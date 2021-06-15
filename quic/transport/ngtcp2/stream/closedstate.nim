import ../../../basics
import ../../stream

type
  ClosedStream* = ref object of StreamState
  ClosedStreamError* = object of StreamError

proc newClosedStream*(): ClosedStream =
  ClosedStream()

method read(state: ClosedStream): Future[seq[byte]] {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

method write(state: ClosedStream, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

method close(state: ClosedStream) {.async.} =
  discard
