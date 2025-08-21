import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ./basestream

type ClosedStream* = ref object of BaseStream
  wasReset: bool

proc newClosedStream*(
    incoming: AsyncQueue[seq[byte]], frameSorter: FrameSorter, wasReset: bool = false
): ClosedStream =
  ClosedStream(incoming: incoming, wasReset: wasReset)

method enter*(state: ClosedStream, stream: Stream) =
  discard

method leave*(state: ClosedStream) =
  discard

method read*(state: ClosedStream): Future[seq[byte]] {.async.} =
  # If stream was reset, always throw exception
  if state.wasReset:
    raise newException(ClosedStreamError, "stream was reset")

  try:
    return state.incoming.popFirstNoWait()
  except AsyncQueueEmptyError:
    discard

  # When no more data is available, return EOF instead of throwing exception
  return @[]

method write*(state: ClosedStream, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

method close*(state: ClosedStream) {.async.} =
  discard

method closeWrite*(state: ClosedStream) {.async.} =
  discard

method closeRead*(state: ClosedStream) {.async.} =
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
