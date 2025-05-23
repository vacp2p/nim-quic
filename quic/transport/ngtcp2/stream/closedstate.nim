import ../../../basics
import ../../stream
import ../../framesorter
import chronicles

logScope:
  topics = "closed state"

type
  ClosedStream* = ref object of StreamState
    remaining: AsyncQueue[seq[byte]]
    frameSorter: FrameSorter

  ClosedStreamError* = object of StreamError

proc newClosedStream*(
    remaining: AsyncQueue[seq[byte]], frameSorter: FrameSorter
): ClosedStream =
  ClosedStream(remaining: remaining)

method enter*(state: ClosedStream, stream: Stream) =
  discard

method leave*(state: ClosedStream) =
  discard

method read*(state: ClosedStream): Future[seq[byte]] {.async.} =
  try:
    return state.remaining.popFirstNoWait()
  except AsyncQueueEmptyError:
    discard
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

method receive*(state: ClosedStream, offset: uint64, bytes: seq[byte], isFin: bool) =
  discard

method reset*(state: ClosedStream) =
  discard

method expire*(state: ClosedStream) {.raises: [].} =
  discard
