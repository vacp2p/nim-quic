import ../../../basics
import ../../stream
import chronicles

logScope:
  topics = "closed state"

type
  ClosedStream* = ref object of StreamState
  ClosedStreamError* = object of StreamError

proc newClosedStream*(): ClosedStream =
  ClosedStream()

{.push locks: "unknown".}

method enter*(state: ClosedStream, stream: Stream) =
  procCall StreamState(state).enter(stream)
  stream.closed.fire()

method read*(state: ClosedStream): Future[seq[byte]] {.async.} =
  trace "cant read, stream is closed"
  raise newException(ClosedStreamError, "stream is closed")

method write*(state: ClosedStream, bytes: seq[byte]) {.async.} =
  trace "cant write, stream is closed"
  raise newException(ClosedStreamError, "stream is closed")

method close*(state: ClosedStream) {.async.} =
  discard

method onClose*(state: ClosedStream) =
  discard

method isClosed*(state: ClosedStream): bool =
  true

{.pop.}
