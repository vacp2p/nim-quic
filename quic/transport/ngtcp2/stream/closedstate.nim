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

method read*(
    state: ClosedStream
): Future[seq[byte]] {.async: (raises: [CancelledError, StreamError, QuicError]).} =
  trace "cant read, stream is closed"
  raise newException(ClosedStreamError, "stream is closed")

method write*(
    state: ClosedStream, bytes: seq[byte]
) {.async: (raises: [StreamError]).} =
  trace "cant write, stream is closed"
  raise newException(ClosedStreamError, "stream is closed")

method close*(state: ClosedStream) {.async: (raises: []).} =
  discard

method onClose*(state: ClosedStream) =
  discard

method isClosed*(state: ClosedStream): bool =
  true

{.pop.}
