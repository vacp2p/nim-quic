import ../../../errors
import ../../../basics
import ../../stream
import ../native/[connection, errors]
import ./queue
import ./basestate

type ClosedStreamState* = ref object of BaseStreamState
  wasReset: bool

proc newClosedStreamState*(
    base: BaseStreamState, wasReset: bool = false
): ClosedStreamState =
  ClosedStreamState(
    connection: base.connection,
    stream: base.stream,
    queue: base.queue,
    finSent: base.finSent,
    wasReset: wasReset,
  )

proc doReset(state: ClosedStreamState) {.raises: [QuicError].} =
  try:
    state.connection.shutdownStream(state.stream.id)
  except Ngtcp2FatalError:
    # do nothing we are already in closed connection
    discard  

proc sendFin(state: ClosedStreamState) =
  if not state.finSent:
    state.finSent = true
    discard state.connection.send(state.stream.id, @[], true)

method onEnter*(state: ClosedStreamState) {.raises: [QuicError].} =
  procCall onEnter(BaseStreamState(state))
  if state.wasReset:
    state.queue.reset()
  state.queue.close()
  if state.wasReset:
    state.doReset()
  else:
    state.sendFin()
  state.stream.closed.fire()

method onLeave*(state: ClosedStreamState) =
  raiseAssert "ClosedStreamState state should never leave"

method read*(
    state: ClosedStreamState
): Future[seq[byte]] {.async: (raises: [CancelledError, QuicError]).} =
  # If stream was reset, always throw exception
  if state.wasReset:
    raise newException(ClosedStreamError, "stream was reset")

  try:
    return state.queue.incoming.popFirstNoWait()
  except AsyncQueueEmptyError:
    discard

  # When no more data is available, return EOF instead of throwing exception
  return @[]

method write*(
    state: ClosedStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  raise newException(ClosedStreamError, "stream is closed")

method close*(
    state: ClosedStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  discard

method closeWrite*(
    state: ClosedStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  discard

method closeRead*(
    state: ClosedStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  discard

method onClose*(state: ClosedStreamState) =
  discard

method isClosed*(state: ClosedStreamState): bool =
  true

method receive*(
    state: ClosedStreamState, offset: uint64, bytes: seq[byte], isFin: bool
) =
  discard

method reset*(state: ClosedStreamState) {.raises: [QuicError].} =
  discard
