import ngtcp2
import results

type
    PicoTLSContext* = ref object
        context*: ptr ptls_context_t
        sign_cert: ptls_sign_certificate_t

    PicoTLSConnection* = ref object
        conn*: ptr ptls_t


proc loadCertificate(ctx: ptr ptls_context_t, certificate: seq[byte]): Result[void, string] = 
    var buf = create(ptls_cred_buffer_t) # TODO: free
    buf.off = 0;
    buf.owns_base = 0;
    buf.len = uint(len(certificate))
    buf.base = newString(buf.len).cstring
    copyMem(buf.base[0].addr, certificate[0].addr,  buf.len )

    let ret = ptls_load_certificates_from_memory(ctx, buf);
    if ret == 0:
        ok()
    else:
        err("could not load certificate: " & $ret)

proc loadPrivateKey(signCert: ptr ptls_openssl_sign_certificate_t, key: seq[byte]): Result[void, string] =
    let ret = ptls_openssl_init_sign_certificate_with_mem_key(signCert, key[0].addr, key.len.cint);
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

    if len(key) != 0 and len(certificate) != 0:
        var signCert = create(ptls_openssl_sign_certificate_t)  # TODO: free
        ?loadPrivateKey(signCert, key)
        ctx.sign_certificate = addr signCert.super

        # TODO: implement custom certificate validation
        
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
