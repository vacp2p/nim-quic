import ../../../basics
import ../../stream
import ../native/connection
import ./queue

type BaseStreamState* = ref object of StreamState
  streamId*: int64
  stream*: Opt[Stream]
  queue*: StreamQueue
  connection*: Ngtcp2Connection
  finSent*: bool

method expire*(state: BaseStreamState) {.raises: [].} =
  let stream = state.stream.valueOr:
    echo "aaaaaaaaaaaaaaaaaaaaaaaa111"
    return
  stream.closed.fire()

method write*(
    state: BaseStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  await state.connection.send(state.streamId, bytes)

proc allowMoreIncomingBytes*(state: BaseStreamState, amount: uint64) =
  state.connection.extendStreamOffset(state.streamId, amount)
  state.connection.send()

proc sendFin*(state: BaseStreamState, stream: stream.Stream) =
  if not state.finSent:
    state.finSent = true
    discard state.connection.send(stream.id, @[], true)

proc reset*(state: BaseStreamState, stream: stream.Stream) {.raises: [QuicError].} =
  state.connection.shutdownStream(stream.id)

proc switch*(state: BaseStreamState, newStream: StreamState) {.raises: [QuicError].} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newStream)
