import results
import ngtcp2/native/picotls
import ngtcp2

type
  TLSBackend* = ref object
    picoTLS*: PicoTLSContext

proc init*(t: typedesc[TLSBackend], isServer: bool, certificate: seq[byte], key: seq[byte]): Result[TLSBackend, string] =
  let picotlsCtx = ?PicoTLSContext.init(certificate, key)
  if isServer:
    let ret = ngtcp2_crypto_picotls_configure_server_context(picotlsCtx.context)
    if ret != 0:
      return err("could not configure server context: " & $ret)
  else:
    let ret = ngtcp2_crypto_picotls_configure_client_context(picotlsCtx.context) 
    if ret != 0:
      return err("could not configure client context: " & $ret)
    
  ok(TLSBackend(picoTLS: picotlsCtx))

proc destroy*(self: TLSBackend) =
  self.picoTLS.destroy()
  self.picoTLS = nil