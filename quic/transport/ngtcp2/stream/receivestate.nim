import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ../native/connection
import ./basestate
import ./closestate

type ReceiveStreamState* = ref object of BaseStreamState

proc newReceiveStreamState*(base: BaseStreamState): ReceiveStreamState =
  ReceiveStreamState(
    connection: base.connection, incoming: base.incoming, frameSorter: base.frameSorter
  )

method enter*(state: ReceiveStreamState, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)

method leave*(state: ReceiveStreamState) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: ReceiveStreamState): Future[seq[byte]] {.async.} =
  # Check for immediate EOF conditions
  if state.frameSorter.isEOF() and state.incoming.len == 0:
    let stream = state.stream.valueOr:
      return @[] # Already closed
    stream.switch(newClosedStreamState(state))
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  # Get data from incoming queue
  let data = await state.incoming.get()

  # If we got real data, return it with flow control update
  if data.len > 0:
    state.allowMoreIncomingBytes(data.len.uint64)
    return data

  # If we got empty data (len == 0), check if this is EOF
  if data.len == 0 and state.frameSorter.isEOF():
    # This is EOF - stream has been closed with FIN bit from remote
    let stream = state.stream.valueOr:
      return @[] # Already closed
    # If local read is also closed, switch to ClosedStream
    stream.switch(newClosedStreamState(state))
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF; continue reading for more data
  return await state.read()

method write*(state: ReceiveStreamState, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "write side is closed")

method close*(state: ReceiveStreamState) {.async.} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStreamState(state))

method closeWrite*(state: ReceiveStreamState) {.async.} =
  discard

method closeRead*(state: ReceiveStreamState) {.async.} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStreamState(state))

method onClose*(state: ReceiveStreamState) =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStreamState(state))

method isClosed*(state: ReceiveStreamState): bool =
  false

method receive*(
    state: ReceiveStreamState, offset: uint64, bytes: seq[byte], isFin: bool
) =
  state.frameSorter.insert(offset, bytes, isFin)

  if state.frameSorter.isComplete():
    let stream = state.stream.valueOr:
      return
    stream.closed.fire()
    stream.switch(newClosedStreamState(state))

method reset*(state: ReceiveStreamState) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStreamState(state, wasReset = true))
