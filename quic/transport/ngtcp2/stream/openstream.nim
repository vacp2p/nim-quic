import ../../../basics
import ../../framesorter
import ../../stream
import ../native/connection
import ./basestream
import ./closestream
import ./receivestream
import ./sendstream
import ./helpers

type OpenStream* = ref object of BaseStream

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  let incomingQ = newAsyncQueue[seq[byte]]()
  OpenStream(
    connection: connection, incoming: incomingQ, frameSorter: initFrameSorter(incomingQ)
  )

method enter*(state: OpenStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  setUserData(state.stream, state.connection, unsafeAddr state[])

method leave*(state: OpenStream) =
  setUserData(state.stream, state.connection, nil)
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: OpenStream): Future[seq[byte]] {.async.} =
  # Check for immediate EOF conditions
  if state.frameSorter.isEOF() and state.incoming.len == 0:
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  # Get data from incoming queue
  let data = await state.incoming.get()

  # If we got real data, return it with flow control update
  if data.len > 0:
    allowMoreIncomingBytes(state.stream, state.connection, data.len.uint64)
    return data

  # If we got empty data (len == 0), check if this is EOF
  if data.len == 0 and state.frameSorter.isEOF():
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF; continue reading for more data
  return await state.read()

method write*(state: OpenStream, bytes: seq[byte]): Future[void] =
  state.connection.send(state.stream.get.id, bytes)

method close*(state: OpenStream) {.async.} =
  # Bidirectional streams, close() only closes the send side of the stream.
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newReceiveStream(state.connection, state.incoming, state.frameSorter))

method closeWrite*(state: OpenStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newReceiveStream(state.connection, state.incoming, state.frameSorter))

method closeRead*(state: OpenStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  stream.switch(newSendStream(state.connection, state.incoming, state.frameSorter))

method onClose*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return

  # Wake up pending read() operations before switching states
  # This fixes race condition when ngtcp2 calls onClose() while read() is waiting
  try:
    state.incoming.putNoWait(@[]) # Send EOF marker to wake up pending reads
  except AsyncQueueFullError:
    # Queue is full, that's fine - there's already data to process
    discard

  stream.switch(newClosedStream(state.incoming, state.frameSorter))

method isClosed*(state: OpenStream): bool =
  false

method receive*(state: OpenStream, offset: uint64, bytes: seq[byte], isFin: bool) =
  let stream = state.stream.valueOr:
    return

  state.frameSorter.insert(offset, bytes, isFin)

  if state.frameSorter.isComplete():
    stream.closed.fire()
    stream.switch(newClosedStream(state.incoming, state.frameSorter))

method reset*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state.incoming, state.frameSorter, wasReset = true))

method expire*(state: OpenStream) {.raises: [].} =
  expire(state.stream)
