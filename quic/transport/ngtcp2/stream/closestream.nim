import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ../native/connection
import ./basestream

type ClosedStream* = ref object of BaseStream
  wasReset: bool

proc newClosedStream*(base: BaseStream, wasReset: bool = false): ClosedStream =
  ClosedStream(
    connection: base.connection,
    incoming: base.incoming,
    frameSorter: base.frameSorter,
    wasReset: wasReset,
  )

method enter*(state: ClosedStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)
  state.frameSorter.close()

method leave*(state: ClosedStream) =
  doAssert false, "ClosedStream state should never leave"

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
