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
    wasReset: bool

  ClosedStreamError* = object of StreamError

proc newClosedStream*(
    remaining: AsyncQueue[seq[byte]], frameSorter: FrameSorter, wasReset: bool = false
): ClosedStream =
  ClosedStream(remaining: remaining, wasReset: wasReset)

method enter*(state: ClosedStream, stream: Stream) =
  discard

method leave*(state: ClosedStream) =
  discard

method read*(state: ClosedStream): Future[seq[byte]] {.async.} =
  # If stream was reset, always throw exception
  if state.wasReset:
    raise newException(ClosedStreamError, "stream was reset")

  try:
    return state.remaining.popFirstNoWait()
  except AsyncQueueEmptyError:
    discard

  # When no more data is available, return EOF instead of throwing exception
  return @[] # Return EOF for closed streams

method write*(state: ClosedStream, bytes: seq[byte]) {.async.} =
  trace "cant write, stream is closed"
  raise newException(ClosedStreamError, "stream is closed")

method close*(state: ClosedStream) {.async.} =
  discard

method closeWrite*(state: ClosedStream) {.async.} =
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
