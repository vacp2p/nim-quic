import ../../../basics
import ../../stream
import ../native/connection
import ./queue

type BaseStreamState* = ref object of StreamState
  connection*: Ngtcp2Connection
  stream*: Stream
  queue*: StreamQueue
  finSent*: bool

method onEnter*(state: BaseStreamState) {.raises: [QuicError].} =
  procCall onEnter(StreamState(state))

method onLeave*(state: BaseStreamState) =
  procCall onLeave(StreamState(state))

method expire*(state: BaseStreamState) {.raises: [].} =
  state.stream.closed.fire()

method write*(
    state: BaseStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  await state.connection.send(state.stream.id, bytes)

proc allowMoreIncomingBytes*(state: BaseStreamState, amount: uint64) =
  state.connection.extendStreamOffset(state.stream.id, amount)
  state.connection.send()

proc sendFin*(state: BaseStreamState) =
  if not state.finSent:
    state.finSent = true
    discard state.connection.send(state.stream.id, @[], true)

proc reset*(state: BaseStreamState) {.raises: [QuicError].} =
  state.connection.shutdownStream(state.stream.id)

proc switch*(state: BaseStreamState, nextState: StreamState) {.raises: [QuicError].} =
  state.stream.switch(nextState)
