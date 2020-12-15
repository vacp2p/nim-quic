import pkg/chronos
import ../../stream

type
  ClosedStream* = ref object of StreamState
  ClosedStreamError* = object of StreamError

method read(state: ClosedStream, stream: Stream): Future[seq[byte]] {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

method write(state: ClosedStream, stream: Stream, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

method close(state: ClosedStream, stream: Stream) {.async.} =
  discard

method destroy(state: ClosedStream) =
  discard

proc newClosedStream*(): ClosedStream =
  ClosedStream()
