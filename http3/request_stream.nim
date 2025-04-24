import httpclient
import ./errors
import ../quic/api

type HTTP3RequestStream* = object
  quicStream: api.Stream

proc init*(
    t: typedesc[HTTP3RequestStream], quicStream: api.Stream
): HTTP3RequestStream =
  return HTTP3RequestStream(quicStream: quicStream)

proc sendRequestHeader*(s: HTTP3RequestStream) {.raises: [HTTP3Error].} =
  discard

proc readResponse*(
    s: HTTP3RequestStream
): httpclient.Response {.raises: [HTTP3Error].} =
  discard

proc streamID*(s: HTTP3RequestStream): int64 =
  return s.quicStream.id()

proc writeData*(s: HTTP3RequestStream, buf: ptr uint8, buflen: csize_t) =
  discard
