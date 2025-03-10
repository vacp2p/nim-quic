import results
import ngtcp2
import std/sets
import ./ngtcp2/native
import ../errors

export CertificateVerifier
export certificateVerifierCB
export CustomCertificateVerifier
export InsecureCertificateVerifier
export init
export destroy

type TLSBackend* = ref object
  picoTLS*: PicoTLSContext

proc newServerTLSBackend*(
    certificate: seq[byte],
    key: seq[byte],
    alpn: HashSet[string] = initHashSet[string](),
    certificateVerifier: Opt[CertificateVerifier],
): TLSBackend {.raises: [QuicError].} =
  let picotlsCtx = PicoTLSContext.init(
    certificate, key, alpn, certificateVerifier, certificateVerifier.isSome
  )
  let ret = ngtcp2_crypto_picotls_configure_server_context(picotlsCtx.context)
  if ret != 0:
    raise newException(QuicError, "could not configure server context: " & $ret)
  return TLSBackend(picoTLS: picotlsCtx)

proc newClientTLSBackend*(
    certificate: seq[byte],
    key: seq[byte],
    alpn: HashSet[string] = initHashSet[string](),
    certificateVerifier: Opt[CertificateVerifier],
): TLSBackend {.raises: [QuicError].} =
  let picotlsCtx =
    PicoTLSContext.init(certificate, key, alpn, certificateVerifier, false)
  let ret = ngtcp2_crypto_picotls_configure_client_context(picotlsCtx.context)
  if ret != 0:
    raise newException(QuicError, "could not configure client context: " & $ret)
  return TLSBackend(picoTLS: picotlsCtx)

proc destroy*(self: TLSBackend) =
  if self.picoTLS.isNil:
    return

  self.picoTLS.destroy()
  self.picoTLS = nil
