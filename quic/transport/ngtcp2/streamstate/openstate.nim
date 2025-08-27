import ../../../basics
import ../../framesorter
import ../../stream
import ../native/connection
import ./basestate
import ./closestate
import ./receivestate
import ./sendstate

type OpenStreamState* = ref object of BaseStreamState

proc newOpenStreamState*(connection: Ngtcp2Connection): OpenStreamState =
  let incomingQ = newAsyncQueue[seq[byte]]()
  OpenStreamState(
    connection: connection, incoming: incomingQ, frameSorter: initFrameSorter(incomingQ)
  )

method enter*(state: OpenStreamState, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)

method leave*(state: OpenStreamState) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: OpenStreamState): Future[seq[byte]] {.async.} =
  # Check for immediate EOF conditions
  if state.frameSorter.isEOF() and state.incoming.len == 0:
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  let data = await state.incoming.get()

  # If we got data, return it with flow control update
  if data.len > 0:
    state.allowMoreIncomingBytes(data.len.uint64)
    return data

  # Empty data (len == 0) and this is EOF
  if state.frameSorter.isEOF():
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF; continue reading for more data
  return await state.read()

method write*(state: OpenStreamState, bytes: seq[byte]) {.async.} =
  await state.writeToStream(bytes)

method close*(state: OpenStreamState) {.async.} =
  state.switch(newReceiveStreamState(state))

method closeWrite*(state: OpenStreamState) {.async.} =
  state.switch(newReceiveStreamState(state))

method closeRead*(state: OpenStreamState) {.async.} =
  state.switch(newSendStreamState(state))

method onClose*(state: OpenStreamState) =
  state.switch(newClosedStreamState(state))

method isClosed*(state: OpenStreamState): bool =
  false

method receive*(state: OpenStreamState, offset: uint64, bytes: seq[byte], isFin: bool) =
  state.frameSorter.insert(offset, bytes, isFin)
  if state.frameSorter.isComplete():
    state.switch(newClosedStreamState(state))

method reset*(state: OpenStreamState) =
  state.switch(newClosedStreamState(state, wasReset = true))
