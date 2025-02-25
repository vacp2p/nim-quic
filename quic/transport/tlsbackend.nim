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

type TLSBackend* = ref object
  picoTLS*: PicoTLSContext

proc init*(
    t: typedesc[TLSBackend],
    isServer: bool,
    certificate: seq[byte],
    key: seq[byte],
    certificateVerifier: Opt[CertificateVerifier],
): TLSBackend {.raises: [QuicError].} =
  let picotlsCtx = PicoTLSContext.init(certificate, key, certificateVerifier)
  if isServer:
    let ret = ngtcp2_crypto_picotls_configure_server_context(picotlsCtx.context)
    if ret != 0:
      raise newException(QuicError, "could not configure server context: " & $ret)
  else:
    let ret = ngtcp2_crypto_picotls_configure_client_context(picotlsCtx.context)
    if ret != 0:
      raise newException(QuicError, "could not configure client context: " & $ret)

  return TLSBackend(picoTLS: picotlsCtx)

proc destroy*(self: TLSBackend) =
  self.picoTLS.destroy()
  self.picoTLS = nil
