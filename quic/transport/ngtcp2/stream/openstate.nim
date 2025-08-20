import ../../../basics
import ../../framesorter
import ../../stream
import ./helpers
import ../native/connection
import ./closedstate
import ./writeclosedstate

type OpenStream* = ref object of StreamState
  stream*: Opt[Stream]
  incoming*: AsyncQueue[seq[byte]]
  connection*: Ngtcp2Connection
  frameSorter*: FrameSorter

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
  # RFC 9000 compliant stream reading logic
  # Priority 1: Check for immediate EOF conditions
  if state.frameSorter.isEOF() and state.incoming.len == 0:
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  # Priority 2: Get data from incoming queue
  let data = await state.incoming.get()

  # If we got real data, return it with flow control update
  if data.len > 0:
    allowMoreIncomingBytes(state.stream, state.connection, data.len.uint64)
    return data

  # If we got empty data (len == 0), check if this is EOF
  if data.len == 0 and state.frameSorter.isEOF():
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF - this shouldn't happen in normal operation
  # Continue reading for more data
  return await state.read()

method write*(state: OpenStream, bytes: seq[byte]): Future[void] =
  # let stream = state.stream.valueOr:
  #   raise newException(QuicError, "stream is closed")
  # See https://github.com/status-im/nim-quic/pull/41 for more details
  state.connection.send(state.stream.get.id, bytes)

method close*(state: OpenStream) {.async.} =
  ## Close both write and read sides of the stream
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(
    newWriteClosedStream(state.connection, state.incoming, state.frameSorter)
  )

method closeWrite*(state: OpenStream) {.async.} =
  ## Close write side by sending FIN, but keep read side open
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(
    newWriteClosedStream(state.connection, state.incoming, state.frameSorter)
  )

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
  elif isFin and bytes.len == 0 and state.frameSorter.isEOF():
    # Special handling: FIN with no data and we've reached EOF
    # Peer has finished sending data, but we don't switch to ClosedStream automatically
    # because we might still need to write back (half-close scenario)
    # Don't switch to ClosedStream - stay in OpenStream so we can still write
    discard

method reset*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state.incoming, state.frameSorter, wasReset = true))

method expire*(state: OpenStream) {.raises: [].} =
  expire(state.stream)
