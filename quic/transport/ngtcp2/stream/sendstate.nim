import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ../native/connection
import ./basestate
import ./closestate

type SendStreamState* = ref object of BaseStreamState

proc newSendStreamState*(base: BaseStreamState): SendStreamState =
  SendStreamState(
    connection: base.connection, incoming: base.incoming, frameSorter: base.frameSorter
  )

method enter*(state: SendStreamState, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)
  state.frameSorter.close()

method leave*(state: SendStreamState) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: SendStreamState): Future[seq[byte]] {.async.} =
  raise newException(ClosedStreamError, "read side is closed")

method write*(state: SendStreamState, bytes: seq[byte]) {.async.} =
  await state.connection.send(state.stream.get.id, bytes)

method close*(state: SendStreamState) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newClosedStreamState(state))

method closeWrite*(state: SendStreamState) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newClosedStreamState(state))

method closeRead*(stream: SendStreamState) {.async.} =
  discard

method onClose*(state: SendStreamState) =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStreamState(state))

method isClosed*(state: SendStreamState): bool =
  false

method receive*(state: SendStreamState, offset: uint64, bytes: seq[byte], isFin: bool) =
  discard

method reset*(state: SendStreamState) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStreamState(state, wasReset = true))
