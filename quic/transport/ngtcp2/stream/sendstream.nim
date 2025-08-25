import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ../native/connection
import ./basestream
import ./closestream

type SendStream* = ref object of BaseStream

proc newSendStream*(base: BaseStream): SendStream =
  SendStream(
    connection: base.connection, incoming: base.incoming, frameSorter: base.frameSorter
  )

method enter*(state: SendStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)
  state.frameSorter.close()

method leave*(state: SendStream) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: SendStream): Future[seq[byte]] {.async.} =
  raise newException(ClosedStreamError, "read side is closed")

method write*(state: SendStream, bytes: seq[byte]) {.async.} =
  await state.connection.send(state.stream.get.id, bytes)

method close*(state: SendStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newClosedStream(state))

method closeWrite*(state: SendStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newClosedStream(state))

method closeRead*(stream: SendStream) {.async.} =
  discard

method onClose*(state: SendStream) =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStream(state))

method isClosed*(state: SendStream): bool =
  false

method receive*(state: SendStream, offset: uint64, bytes: seq[byte], isFin: bool) =
  discard

method reset*(state: SendStream) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state, wasReset = true))