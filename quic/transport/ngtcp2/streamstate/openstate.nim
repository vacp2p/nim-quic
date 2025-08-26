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

  # Get data from incoming queue
  let data = await state.incoming.get()

  # If we got real data, return it with flow control update
  if data.len > 0:
    state.allowMoreIncomingBytes(data.len.uint64)
    return data

  # If we got empty data (len == 0), check if this is EOF
  if data.len == 0 and state.frameSorter.isEOF():
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF; continue reading for more data
  return await state.read()

method write*(state: OpenStreamState, bytes: seq[byte]): Future[void] =
  state.connection.send(state.stream.get.id, bytes)

method close*(state: OpenStreamState) {.async.} =
  # Bidirectional streams, close() only closes the send side of the stream.
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newReceiveStreamState(state))

method closeWrite*(state: OpenStreamState) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newReceiveStreamState(state))

method closeRead*(state: OpenStreamState) {.async.} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newSendStreamState(state))

method onClose*(state: OpenStreamState) =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStreamState(state))

method isClosed*(state: OpenStreamState): bool =
  false

method receive*(state: OpenStreamState, offset: uint64, bytes: seq[byte], isFin: bool) =
  state.frameSorter.insert(offset, bytes, isFin)

  if state.frameSorter.isComplete():
    let stream = state.stream.valueOr:
      return
    stream.closed.fire()
    stream.switch(newClosedStreamState(state))

method reset*(state: OpenStreamState) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStreamState(state, wasReset = true))
