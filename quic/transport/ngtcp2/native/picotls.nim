import ngtcp2
import results

type
    PicoTLSContext = ref object
        context: ptls_context_t
        sign_cert: ptls_sign_certificate_t

    PicoTLSConnection = ref object
        conn: ptr ptls_t # TODO: destructor


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
    var signCert: ptls_openssl_sign_certificate_t 

    loadPrivateKey(addr signCert, key)

    var ctx: ptls_context_t
    ctx.context.random_bytes = ptls_openssl_random_bytes
    ctx.get_time = ptls_get_time
    ctx.key_exchanges = ptls_openssl_key_exchanges
    ctx.cipher_suites = ptls_openssl_cipher_suites
    ctx.sign_certificate = addr t.super
    
    # TODO: implement custom certificate validation

    ?loadCertificate(addr ctx, certificate)

    ok(PicoTLSContext(
        context: ctx,
    ))
  
proc newConnection*(p: PicoTLSContext, isServer: bool): PicoTLSConnection =
    return PicoTLSConnection(
        conn: if isServer:
        ptls_server_new(addr p.context)
    else:
        ptls_client_new(addr p.context)
    )