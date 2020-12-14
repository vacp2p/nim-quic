import pkg/chronos
import ../../stream
import ./state

type
  ClosedStream* = ref object of StreamState
  ClosedStreamError* = object of StreamError

proc read(stream: Stream, state: ClosedStream): Future[seq[byte]] {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

proc write(stream: Stream, state: ClosedStream, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

proc close(stream: Stream, state: ClosedStream) {.async.} =
  discard

proc destroy(state: ClosedStream) =
  discard

proc newClosedState*(): ClosedStream =
  newState[ClosedStream]()
