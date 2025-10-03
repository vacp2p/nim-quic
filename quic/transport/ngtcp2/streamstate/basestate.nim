import ../../../basics
import ../../stream
import ../native/connection
import ./queue

type BaseStreamState* = ref object of StreamState
  stream*: Opt[Stream]
  queue*: StreamQueue
  connection*: Ngtcp2Connection
  finSent*: bool

method expire*(state: BaseStreamState) {.raises: [].} =
  let stream = state.stream.valueOr:
    return
  stream.closed.fire()

method write*(
    state: BaseStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  let stream = state.stream.valueOr:
    return
  await state.connection.send(stream.id, bytes)

proc setUserData*(
    state: BaseStreamState, stream: stream.Stream
) {.raises: [QuicError].} =
  state.connection.setStreamUserData(stream.id, unsafeAddr state[])

proc allowMoreIncomingBytes*(state: BaseStreamState, amount: uint64) =
  let stream = state.stream.valueOr:
    return
  state.connection.extendStreamOffset(stream.id, amount)
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
