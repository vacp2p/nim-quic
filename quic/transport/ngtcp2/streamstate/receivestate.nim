import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ./basestate
import ./closestate

type ReceiveStreamState* = ref object of BaseStreamState

proc newReceiveStreamState*(base: BaseStreamState): ReceiveStreamState =
  ReceiveStreamState(
    connection: base.connection,
    incoming: base.incoming,
    frameSorter: base.frameSorter,
    finSent: base.finSent,
  )

method enter*(state: ReceiveStreamState, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)
  state.sendFin(stream)

method leave*(state: ReceiveStreamState) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: ReceiveStreamState): Future[seq[byte]] {.async.} =
  # Check for immediate EOF conditions
  if state.frameSorter.isEOF() and state.incoming.len == 0:
    state.switch(newClosedStreamState(state))
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  let data = await state.incoming.get()

  # If we got data, return it with flow control update
  if data.len > 0:
    state.allowMoreIncomingBytes(data.len.uint64)
    return data

  # Empty data (len == 0) and this is EOF
  if state.frameSorter.isEOF():
    state.switch(newClosedStreamState(state))
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF; continue reading for more data
  return await state.read()

method write*(state: ReceiveStreamState, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "write side is closed")

method close*(state: ReceiveStreamState) {.async.} =
  state.switch(newClosedStreamState(state))

method closeWrite*(state: ReceiveStreamState) {.async.} =
  discard

method closeRead*(state: ReceiveStreamState) {.async.} =
  state.switch(newClosedStreamState(state))

method onClose*(state: ReceiveStreamState) =
  state.switch(newClosedStreamState(state))

method isClosed*(state: ReceiveStreamState): bool =
  false

method receive*(
    state: ReceiveStreamState, offset: uint64, bytes: seq[byte], isFin: bool
) =
  state.frameSorter.insert(offset, bytes, isFin)
  if state.frameSorter.isComplete():
    state.switch(newClosedStreamState(state))

method reset*(state: ReceiveStreamState) =
  state.switch(newClosedStreamState(state, wasReset = true))
