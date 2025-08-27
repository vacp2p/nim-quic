import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ./basestate
import ./closestate

type SendStreamState* = ref object of BaseStreamState

proc newSendStreamState*(base: BaseStreamState): SendStreamState =
  SendStreamState(
    connection: base.connection,
    incoming: base.incoming,
    frameSorter: base.frameSorter,
    finSent: base.finSent,
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
  await state.writeToStream(bytes)

method close*(state: SendStreamState) {.async.} =
  state.switch(newClosedStreamState(state))

method closeWrite*(state: SendStreamState) {.async.} =
  state.switch(newClosedStreamState(state))

method closeRead*(stream: SendStreamState) {.async.} =
  discard

method onClose*(state: SendStreamState) =
  state.switch(newClosedStreamState(state))

method isClosed*(state: SendStreamState): bool =
  false

method receive*(state: SendStreamState, offset: uint64, bytes: seq[byte], isFin: bool) =
  discard

method reset*(state: SendStreamState) =
  state.switch(newClosedStreamState(state, wasReset = true))
