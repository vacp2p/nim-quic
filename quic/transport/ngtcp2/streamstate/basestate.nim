import ../../../basics
import ../../stream
import ../native/connection
import ./queue

type BaseStreamState* = ref object of StreamState
  stream*: Opt[Stream]
  connection*: Ngtcp2Connection
  streamId*: int64
  queue*: StreamQueue
  finSent*: bool

method enter*(state: BaseStreamState, stream: Stream) {.raises: [QuicError].} =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)

method leave*(state: BaseStreamState) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method expire*(state: BaseStreamState) {.raises: [].} =
  let stream = state.stream.valueOr:
    return
  stream.closed.fire()

method write*(
    state: BaseStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  await state.connection.send(state.streamId, bytes)

proc allowMoreIncomingBytes*(state: BaseStreamState, amount: uint64) =
  state.connection.extendStreamOffset(state.streamId, amount)
  state.connection.send()

proc sendFin*(state: BaseStreamState) =
  if not state.finSent:
    state.finSent = true
    discard state.connection.send(state.streamId, @[], true)

proc reset*(state: BaseStreamState) {.raises: [QuicError].} =
  state.connection.shutdownStream(state.streamId)

proc switch*(state: BaseStreamState, newStream: StreamState) {.raises: [QuicError].} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newStream)
