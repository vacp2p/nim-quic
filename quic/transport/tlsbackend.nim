import results
import ngtcp2
import ./ngtcp2/native
import ../errors

export CertificateVerifier
export certificateVerifierCB
export CustomCertificateVerifier
export InsecureCertificateVerifier
export init
export destroy

export TLSBackendSetupError

type TLSBackend* = ref object
  picoTLS*: PicoTLSContext

proc newServerTLSBackend*(
    certificate: seq[byte],
    key: seq[byte],
    certificateVerifier: Opt[CertificateVerifier],
): TLSBackend {.raises: [TLSBackendSetupError].} =
  let picotlsCtx = PicoTLSContext.init(
    certificate, key, certificateVerifier, certificateVerifier.isSome
  )
  let ret = ngtcp2_crypto_picotls_configure_server_context(picotlsCtx.context)
  if ret != 0:
    raise
      newException(TLSBackendSetupError, "could not configure server context: " & $ret)
  return TLSBackend(picoTLS: picotlsCtx)

proc newClientTLSBackend*(
    certificate: seq[byte],
    key: seq[byte],
    certificateVerifier: Opt[CertificateVerifier],
): TLSBackend {.raises: [TLSBackendSetupError].} =
  let picotlsCtx = PicoTLSContext.init(certificate, key, certificateVerifier, false)
  let ret = ngtcp2_crypto_picotls_configure_client_context(picotlsCtx.context)
  if ret != 0:
    raise
      newException(TLSBackendSetupError, "could not configure client context: " & $ret)
  return TLSBackend(picoTLS: picotlsCtx)

proc destroy*(self: TLSBackend) =
  self.picoTLS.destroy()
  self.picoTLS = nil
