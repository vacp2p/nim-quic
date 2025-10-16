import chronicles
import ngtcp2
import results
import std/sets
import ../../version
import ../../../errors
import ./types
import ./certificateverifier
import ./certificates

const BORINGSSL_OK = 1

proc alpnStr*(tlsCtx: TLSContext): string =
  var list = newString(0)
  for alpn in tlsCtx.alpn:
    list.add chr(alpn.len)
    list.add alpn
  return list

proc toX509(pemCertificate: seq[byte]): ptr X509 =
  var
    bio = BIO_new_mem_buf(addr pemCertificate[0], ossl_ssize_t(pemCertificate.len))
    x509 = PEM_read_bio_X509(bio, nil, nil, nil)
  if BIO_free(bio) != BORINGSSL_OK:
    raise newException(QuicError, "could not free x509 bio")
  x509

proc toPKey(pemKey: seq[byte]): ptr EVP_PKEY =
  var
    bio = BIO_new_mem_buf(addr pemKey[0], ossl_ssize_t(pemKey.len))
    p = PEM_read_bio_PrivateKey(bio, nil, nil, nil)
  if BIO_free(bio) != BORINGSSL_OK:
    raise newException(QuicError, "could not free pkey bio")
  p

proc alpn_select_proto_cb(
    ssl: ptr SSL,
    outv: ptr ptr uint8,
    outlen: ptr uint8,
    inv: ptr uint8,
    inlen: cuint,
    userData: pointer,
): cint {.cdecl.} =
  let conn_ref = cast[ptr ngtcp2_crypto_conn_ref](SSL_get_ex_data(ssl, 0))
  let nConn = cast[Ngtcp2Connection](conn_ref.user_data)
  let version = ngtcp2_conn_get_client_chosen_version(nConn.conn.get())

  if version != CurrentQuicVersion:
    trace "unexpected quic version", version
    return SSL_TLSEXT_ERR_ALERT_FATAL

  let tlsCtx = cast[TLSContext](userData)
  let alpnStr = tlsCtx.alpnStr()
  if (
    SSL_select_next_proto(
      outv,
      outlen,
      cast[ptr uint8](alpnStr.cstring),
      cast[cuint](alpnStr.len),
      inv,
      inlen,
    ) == OPENSSL_NPN_NEGOTIATED
  ):
    return SSL_TLSEXT_ERR_OK

  return SSL_TLSEXT_ERR_ALERT_FATAL

proc verify_certificate(
    ssl: ptr SSL, out_alert: ptr uint8
): enum_ssl_verify_result_t {.cdecl.} =
  let derCertificates = getFullCertChain(ssl)

  let conn_ref = cast[ptr ngtcp2_crypto_conn_ref](SSL_get_ex_data(ssl, 0))
  let nConn = cast[Ngtcp2Connection](conn_ref.user_data)

  let serverName = SSL_get_servername(ssl, TLSEXT_NAMETYPE_host_name)
  doAssert nConn.tlsContext.certVerifier.isSome, "no custom validator set"
  if nConn.tlsContext.certVerifier.get().verify($serverName, derCertificates):
    return ssl_verify_ok
  else:
    out_alert[] = SSL_AD_CERTIFICATE_UNKNOWN
    return ssl_verify_invalid

proc init*(
    t: typedesc[TLSContext],
    certificate: seq[byte],
    key: seq[byte],
    alpn: HashSet[string],
    certVerifier: Opt[CertificateVerifier],
    requiresClientAuthentication: bool,
    isServer: bool,
): TLSContext =
  var sslCtx = SSL_CTX_new(
    if isServer:
      TLS_server_method()
    else:
      TLS_client_method()
  )

  if sslCtx.isNil:
    raise newException(QuicError, "could not instantiate ssl context")

  var pctx = TLSContext(context: sslCtx, alpn: alpn, certVerifier: certVerifier)

  discard SSL_CTX_set_mode(sslCtx, SSL_MODE_RELEASE_BUFFERS)

  const ssl_opts =
    (SSL_OP_ALL and not SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS) or SSL_OP_SINGLE_ECDH_USE or
    SSL_OP_CIPHER_SERVER_PREFERENCE

  discard SSL_CTX_set_options(sslCtx, uint32(ssl_opts))

  let configureResult =
    if isServer:
      ngtcp2_crypto_boringssl_configure_server_context(sslCtx)
    else:
      ngtcp2_crypto_boringssl_configure_client_context(sslCtx)
  if configureResult != 0:
    raise newException(QuicError, "could not configure tls context")

  if isServer:
    SSL_CTX_set_alpn_select_cb(sslCtx, alpn_select_proto_cb, cast[pointer](pctx))
  else:
    if (
      SSL_CTX_set1_sigalgs_list(sslCtx, "ed25519:ecdsa_secp256r1_sha256") != BORINGSSL_OK
    ):
      raise newException(QuicError, "could not set supported algorithm list")

  if key.len != 0 and certificate.len != 0:
    let pkey = key.toPKey()
    let cert = certificate.toX509()
    defer:
      X509_free(cert)
      EVP_PKEY_free(pkey)

    if SSL_CTX_use_certificate(sslCtx, cert) != BORINGSSL_OK:
      raise newException(QuicError, "could not use certificate")

    if SSL_CTX_use_PrivateKey(sslCtx, pkey) != BORINGSSL_OK:
      raise newException(QuicError, "could not use private key")

    if SSL_CTX_check_private_key(sslCtx) != BORINGSSL_OK:
      raise newException(QuicError, "cant use private key with certificate")

  if certVerifier.isSome:
    var verificationFlags = SSL_VERIFY_PEER
    if requiresClientAuthentication and isServer:
      verificationFlags = verificationFlags or SSL_VERIFY_FAIL_IF_NO_PEER_CERT
    SSL_CTX_set_custom_verify(
      sslCtx, SSL_VERIFY_PEER or SSL_VERIFY_FAIL_IF_NO_PEER_CERT, verifyCertificate
    )

  return pctx

proc destroy*(p: TLSContext) =
  if p.context == nil:
    return
  p.certVerifier = Opt.none(CertificateVerifier)
  SSL_CTX_free(p.context)
  p.context = nil
