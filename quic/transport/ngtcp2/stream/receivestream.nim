import ../../../errors
import ../../../basics
import ../../stream
import ../../framesorter
import ../native/connection
import ./basestream
import ./closestream

type ReceiveStream* = ref object of BaseStream

proc newReceiveStream*(base: BaseStream): ReceiveStream =
  ReceiveStream(
    connection: base.connection, incoming: base.incoming, frameSorter: base.frameSorter
  )

method enter*(state: ReceiveStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(stream)

method leave*(state: ReceiveStream) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: ReceiveStream): Future[seq[byte]] {.async.} =
  # Check for immediate EOF conditions
  if state.frameSorter.isEOF() and state.incoming.len == 0:
    let stream = state.stream.valueOr:
      return @[] # Already closed
    stream.switch(newClosedStream(state))
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
    stream.switch(newClosedStream(state))
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF; continue reading for more data
  return await state.read()

method write*(state: ReceiveStream, bytes: seq[byte]) {.async.} =
  raise newException(ClosedStreamError, "write side is closed")

method close*(state: ReceiveStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStream(state))

method closeWrite*(state: ReceiveStream) {.async.} =
  discard

method closeRead*(state: ReceiveStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStream(state))

method onClose*(state: ReceiveStream) =
  let stream = state.stream.valueOr:
    return

  # Wake up pending read() operations before switching states
  # This fixes race condition when ngtcp2 calls onClose() while read() is waiting
  try:
    state.incoming.putNoWait(@[]) # Send EOF marker to wake up pending reads
  except AsyncQueueFullError:
    # Queue is full, that's fine - there's already data to process
    discard

  stream.switch(newClosedStream(state))

method isClosed*(state: ReceiveStream): bool =
  false

method receive*(state: ReceiveStream, offset: uint64, bytes: seq[byte], isFin: bool) =
  state.frameSorter.insert(offset, bytes, isFin)

  if state.frameSorter.isComplete():
    let stream = state.stream.valueOr:
      return
    stream.closed.fire()
    stream.switch(newClosedStream(state))

method reset*(state: ReceiveStream) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state, wasReset = true))
