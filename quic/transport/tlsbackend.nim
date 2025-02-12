import results
import ngtcp2/native/picotls

type
  TLSBackend* = ref object
    picoTLS*: PicoTLSContext


proc init*(t: typedesc[TLSBackend], certificate: seq[byte], key: seq[byte]): Result[TLSBackend, string] =
    let p = ?PicoTLSContext.init(certificate, key)
    ok(TLSBackend(
        picoTLS: p
    ))
