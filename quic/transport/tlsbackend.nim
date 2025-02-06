import results
import ngtcp2/native/picotls
import ngtcp2
import ../errors

type TLSBackend* = ref object
  picoTLS*: PicoTLSContext

proc init*(
    t: typedesc[TLSBackend], isServer: bool, certificate: seq[byte], key: seq[byte]
): TLSBackend {.raises: [QuicError].} =
  let picotlsCtx = PicoTLSContext.init(certificate, key)
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
