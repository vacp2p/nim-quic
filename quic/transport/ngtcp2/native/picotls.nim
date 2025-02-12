import ngtcp2
import results

type
    PicoTLSContext* = ref object
        context*: ptr ptls_context_t
        sign_cert: ptls_sign_certificate_t

    PicoTLSConnection* = ref object
        conn*: ptr ptls_t # TODO: destructor


proc loadCertificate(ctx: ptr ptls_context_t, certificate: seq[byte]): Result[void, string] = 
    var buf: ptls_cred_buffer_t
    buf.off = 0;
    buf.owns_base = 0;
    buf.len = uint(len(certificate) + 1)
    buf.base = newString(buf.len).cstring # TODO: free?
    copyMem(buf.base[0].addr, certificate.addr,  buf.len )

    let ret = ptls_load_certificates_from_memory(ctx, addr buf);
    if ret == 0:
        ok()
    else:
        err("could not load certificate: " & $ret)

proc loadPrivateKey(signCert: ptr ptls_openssl_sign_certificate_t, key: seq[byte]): Result[void, string] =
    let ret = ptls_openssl_init_sign_certificate_with_mem_key(signCert, addr key, key.len.cint);
    if ret == 0:
        ok()
    else:
        err("could not load private key: " & $ret)

proc init*(t: typedesc[PicoTLSContext], certificate: seq[byte], key: seq[byte]): Result[PicoTLSContext, string] =   
    var ctx = create(ptls_context_t)
    ctx.random_bytes = ptls_openssl_random_bytes
    ctx.get_time = addr ptls_get_time
    ctx.key_exchanges = cast[ptr ptr ptls_key_exchange_algorithm_t](addr ptls_openssl_key_exchanges)
    ctx.cipher_suites = cast[ptr ptr ptls_cipher_suite_t](addr ptls_openssl_cipher_suites)

    var signCert: ptls_openssl_sign_certificate_t  # TODO: malloc and free?

    if len(key) != 0:
        ?loadPrivateKey(addr signCert, key)

    ctx.sign_certificate = addr signCert.super
    
    # TODO: implement custom certificate validation

    if len(certificate) != 0:
        ?loadCertificate(ctx, certificate)

    ok(PicoTLSContext(
        context: ctx,
    ))
  
proc newConnection*(p: PicoTLSContext, isServer: bool): PicoTLSConnection =
    return PicoTLSConnection(
        conn: if isServer:
        ptls_server_new(p.context)
    else:
        ptls_client_new(p.context)
    )

proc destroy*(p: PicoTLSConnection) =
    ptls_free(p.conn)
    p.conn = nil