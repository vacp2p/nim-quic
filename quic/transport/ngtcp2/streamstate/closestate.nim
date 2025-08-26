import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ../native/connection
import ./basestate

type ClosedStreamState* = ref object of BaseStreamState
  wasReset: bool

proc newClosedStreamState*(
    base: BaseStreamState, wasReset: bool = false
): ClosedStreamState =
  ClosedStreamState(
    connection: base.connection,
    incoming: base.incoming,
    frameSorter: base.frameSorter,
    wasReset: wasReset,
  )

method enter*(state: ClosedStreamState, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)
  state.frameSorter.close()

method leave*(state: ClosedStreamState) =
  doAssert false, "ClosedStreamState state should never leave"

method read*(state: ClosedStreamState): Future[seq[byte]] {.async.} =
  # If stream was reset, always throw exception
  if state.wasReset:
    raise newException(ClosedStreamError, "stream was reset")

  try:
    return state.incoming.popFirstNoWait()
  except AsyncQueueEmptyError:
    discard

  # When no more data is available, return EOF instead of throwing exception
  return @[]

method write*(state: ClosedStreamState, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "stream is closed")

method close*(state: ClosedStreamState) {.async.} =
  discard

method closeWrite*(state: ClosedStreamState) {.async.} =
  discard

method closeRead*(state: ClosedStreamState) {.async.} =
  discard

method onClose*(state: ClosedStreamState) =
  discard

method isClosed*(state: ClosedStreamState): bool =
  true

method receive*(
    state: ClosedStreamState, offset: uint64, bytes: seq[byte], isFin: bool
) =
  discard

method reset*(state: ClosedStreamState) =
  discard
