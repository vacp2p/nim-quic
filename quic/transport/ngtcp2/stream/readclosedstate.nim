import ../../../basics
import ../../stream
import ../../framesorter
import ./errors

type ReadClosedStream* = ref object of StreamState
  connection*: Ngtcp2Connection
  incoming: AsyncQueue[seq[byte]]
  frameSorter: FrameSorter

proc newReadClosedStream*(
    connection: Ngtcp2Connection,
    incoming: AsyncQueue[seq[byte]],
    frameSorter: FrameSorter,
): ReadClosedStream =
  ReadClosedStream(connection: connection, incoming: incoming, frameSorter: frameSorter)

method enter*(state: ReadClosedStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  setUserData(state.stream, state.connection, unsafeAddr state[])

method leave*(state: ReadClosedStream) =
  setUserData(state.stream, state.connection, nil)
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: ReadClosedStream): Future[seq[byte]] {.async.} =
  # RFC 9000 compliant stream reading logic
  # Priority 1: Check for immediate EOF conditions
  if state.frameSorter.isEOF() and state.incoming.len == 0:
    let stream = state.stream.valueOr:
      return @[] # Already closed
    stream.switch(newClosedStream(state.incoming, state.frameSorter))
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  # Priority 2: Check if local read is closed but there's still buffered data
  if state.incoming.len == 0:
    # Local read closed and no buffered data - switch to ClosedStream
    let stream = state.stream.valueOr:
      return @[] # Already closed
    stream.switch(newClosedStream(state.incoming, state.frameSorter))
    return @[] # Return EOF for locally closed read

  # Priority 3: Get data from incoming queue
  let data = await state.incoming.get()

  # If we got real data, return it with flow control update
  if data.len > 0:
    allowMoreIncomingBytes(state.stream, state.connection, data.len.uint64)
    return data

  # If we got empty data (len == 0), check if this is EOF
  if data.len == 0 and state.frameSorter.isEOF():
    # This is EOF - stream has been closed with FIN bit from remote
    let stream = state.stream.valueOr:
      return @[] # Already closed
    # If local read is also closed, switch to ClosedStream
    stream.switch(newClosedStream(state.incoming, state.frameSorter))
    return @[] # Return EOF per RFC 9000

  return await state.read()

method write*(state: ReadClosedStream, bytes: seq[byte]) {.async.} =
  state.connection.send(state.stream.get.id, bytes)

method close*(state: ReadClosedStream) {.async.} =
  discard

method closeWrite*(state: ReadClosedStream) {.async.} =
  ## Close write side by sending FIN, but keep read side open
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newClosedStream(state.incoming, state.frameSorter))

method onClose*(state: ReadClosedStream) =
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

method isClosed*(state: ReadClosedStream): bool =
  false

method receive*(
    state: ReadClosedStream, offset: uint64, bytes: seq[byte], isFin: bool
) =
  let stream = state.stream.valueOr:
    return

  state.frameSorter.insert(offset, bytes, isFin)

  if state.frameSorter.isComplete():
    stream.closed.fire()
    stream.switch(newClosedStream(state.incoming, state.frameSorter))
  elif isFin and bytes.len == 0 and state.frameSorter.isEOF():
    # Special handling: FIN with no data and we've reached EOF
    # Peer has finished sending data, but we don't switch to ClosedStream automatically
    # because we might still need to write back (half-close scenario)
    # Don't switch to ClosedStream - stay in OpenStream so we can still write
    discard

method reset*(state: ReadClosedStream) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state.remaining, state.frameSorter, wasReset = true))

method expire*(state: ReadClosedStream) {.raises: [].} =
  let stream = state.stream.valueOr:
    return
  stream.closed.fire()
