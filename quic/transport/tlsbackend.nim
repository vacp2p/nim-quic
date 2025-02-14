import results
import ngtcp2/native/picotls
import ngtcp2

type
  TLSBackend* = ref object
    picoTLS*: PicoTLSContext


proc init*(t: typedesc[TLSBackend], certificate: seq[byte], key: seq[byte]): Result[TLSBackend, string] =
    ok(TLSBackend( 
        picoTLS: ?PicoTLSContext.init(certificate, key)
    ))

proc configureServerContext*(self: TLSBackend): Result[void, string] =
  let ret = ngtcp2_crypto_picotls_configure_server_context(self.picoTLS.context)
  if ret != 0:
    return err("could not configure server context: " & $ret)
  return ok()

proc configureClientContext*(self: TLSBackend): Result[void, string] =
  let ret = ngtcp2_crypto_picotls_configure_client_context(self.picoTLS.context) 
  if ret != 0:
    return err("could not configure client context: " & $ret)
  return ok()

proc destroy*(self: TLSBackend) =
  self.picoTLS.destroy()
  self.picoTLS = nil