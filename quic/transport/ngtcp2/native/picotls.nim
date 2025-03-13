import ngtcp2
import ../../../errors
import results
import std/[sets, tables]
import ./certificateverifier

type
  PicoTLSConnection* = ref object
    conn*: ptr ptls_t

  ClientHello = object of ptls_on_client_hello_t
    parentCtx*: PicoTLSContext

  PicoTLSContext* = ref object
    context*: ptr ptls_context_t
    signCert: ptr ptls_openssl_sign_certificate_t
    alpn*: HashSet[string]
    certVerifier: Opt[CertificateVerifier]
    clientHello: ptr ClientHello

proc loadCertificate(ctx: ptr ptls_context_t, certificate: seq[byte]) =
  var buf = create(ptls_cred_buffer_t)
  defer:
    dealloc(buf)
  buf.off = 0
  buf.owns_base = 0
  buf.len = uint(len(certificate))
  buf.base = newString(buf.len).cstring
  copyMem(buf.base[0].unsafeAddr, certificate[0].unsafeAddr, buf.len)

  let ret = ptls_load_certificates_from_memory(ctx, buf)
  if ret != 0:
    raise newException(QuicError, "could not load certificate: " & $ret)

proc loadPrivateKey(signCert: ptr ptls_openssl_sign_certificate_t, key: seq[byte]) =
  let ret = ptls_openssl_init_sign_certificate_with_mem_key(
    signCert, key[0].unsafeAddr, key.len.cint
  )
  if ret != 0:
    raise newException(QuicError, "could not load private key: " & $ret)

proc onClientHello(
    self: ptr ptls_on_client_hello_t,
    ptls: ptr ptls_t,
    params: ptr ptls_on_client_hello_parameters_t,
): cint {.cdecl.} =
  if params.negotiated_protocols.count == 0:
    return 0
  var alpn = initHashSet[string]()
  for i in 0 ..< int(params.negotiated_protocols.count):
    var proto = newString(params.negotiated_protocols.list.len)
    copyMem(
      proto[0].addr,
      params.negotiated_protocols.list.base,
      params.negotiated_protocols.list.len,
    )
    alpn.incl(proto)

  let clientHello = cast[ptr ClientHello](self)

  if alpn.len == 0 and clientHello.parentCtx.alpn.len == 0:
    return 0 # No protocol negotiation required

  var alpnMatch = (clientHello.parentCtx.alpn * alpn)
  if len(alpnMatch) == 0:
    return PTLS_ALERT_NO_APPLICATION_PROTOCOL

  let proto = alpnMatch.pop()
  if ptls_set_negotiated_protocol(ptls, proto.cstring, csize_t(proto.len)) != 0:
    return -1

  return 0

proc init*(
    t: typedesc[PicoTLSContext],
    certificate: seq[byte],
    key: seq[byte],
    alpn: HashSet[string],
    certVerifier: Opt[CertificateVerifier],
    requiresClientAuthentication: bool,
): PicoTLSContext =
  var ctx = create(ptls_context_t)
  ctx.random_bytes = ptls_openssl_random_bytes
  ctx.get_time = addr ptls_get_time
  ctx.key_exchanges =
    cast[ptr ptr ptls_key_exchange_algorithm_t](addr ptls_openssl_key_exchanges)
  ctx.cipher_suites = cast[ptr ptr ptls_cipher_suite_t](addr ptls_openssl_cipher_suites)

  if certVerifier.isSome:
    if requiresClientAuthentication:
      ctx.require_client_authentication = 1
    try:
      ctx.verify_certificate = certVerifier.get().getPtlsVerifyCertificateT()
    except:
      doAssert false, "checked with if"
  else:
    ctx.verify_certificate = nil

  var signCert: ptr ptls_openssl_sign_certificate_t = nil
  if len(key) != 0 and len(certificate) != 0:
    signCert = create(ptls_openssl_sign_certificate_t)
    loadPrivateKey(signCert, key)
    loadCertificate(ctx, certificate)
    ctx.sign_certificate = addr signCert.super

  var pctx = PicoTLSContext(
    context: ctx,
    signCert: signCert,
    alpn: alpn,
    certVerifier: certVerifier,
    clientHello: create(ClientHello),
  )

  pctx.clientHello = create(ClientHello)
  pctx.clientHello.parentCtx = pctx
  ctx.on_client_hello = pctx.clientHello
  ctx.on_client_hello.cb = onClientHello

  return pctx

proc cfree(p: pointer) {.importc: "free", header: "<stdlib.h>".}

proc destroy*(p: PicoTLSContext) =
  if p.context == nil:
    return

  if not p.signCert.isNil:
    ptls_openssl_dispose_sign_certificate(p.signCert)
    let arr = cast[ptr UncheckedArray[ptls_iovec_t]](p.context.certificates.list)
    for i in 0 ..< p.context.certificates.count: #
      cfree(arr[i].base)
    cfree(p.context.certificates.list)
    dealloc(p.signCert)
    p.context.certificates.list = nil
    p.context.certificates.count = 0
    p.signCert = nil

  if p.certVerifier.isSome:
    try:
      p.certVerifier.get().destroy()
    except:
      doAssert false, "checked with if"
    p.certVerifier = Opt.none(CertificateVerifier)

  dealloc(p.clientHello)
  p.clientHello = nil

  dealloc(p.context)
  p.context = nil

proc newConnection*(p: PicoTLSContext, isServer: bool): PicoTLSConnection =
  return PicoTLSConnection(
    conn:
      if isServer:
        ptls_server_new(p.context)
      else:
        ptls_client_new(p.context)
  )

proc destroy*(p: PicoTLSConnection) =
  if p.conn == nil:
    return

  ptls_free(p.conn)
  p.conn = nil
