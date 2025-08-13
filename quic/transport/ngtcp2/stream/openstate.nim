import ../../../basics
import ../../framesorter
import ../../stream
import ./helpers
import ../native/connection
import ./closedstate
import chronicles

logScope:
  topics = "open state"

type OpenStream* = ref object of StreamState
  stream*: Opt[Stream]
  incoming*: AsyncQueue[seq[byte]]
  connection*: Ngtcp2Connection
  frameSorter*: FrameSorter
  closeFut*: Future[string]
  writeFinSent*: bool
  readClosed*: bool

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  let incomingQ = newAsyncQueue[seq[byte]]()
  OpenStream(
    connection: connection,
    incoming: incomingQ,
    closeFut: newFuture[string](),
    frameSorter: initFrameSorter(incomingQ),
    writeFinSent: false,
    readClosed: false,
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
    # Remote sent FIN and no more data - check if we should switch to ClosedStream
    if state.readClosed:
      # Both remote FIN received and local read closed - switch to ClosedStream
      let stream = state.stream.valueOr:
        return @[] # Already closed
      stream.switch(newClosedStream(state.incoming, state.frameSorter))
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  # Priority 2: Check if local read is closed but there's still buffered data
  if state.readClosed and state.incoming.len == 0:
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
    if state.readClosed:
      stream.switch(newClosedStream(state.incoming, state.frameSorter))
    return @[] # Return EOF per RFC 9000

  # If local read is closed but we got empty data (not EOF), return EOF
  if state.readClosed:
    let stream = state.stream.valueOr:
      return @[] # Already closed
    stream.switch(newClosedStream(state.incoming, state.frameSorter))
    return @[] # Return EOF for locally closed read

  # Empty data but no EOF - this shouldn't happen in normal operation
  # Continue reading for more data
  return await state.read()

method write*(state: OpenStream, bytes: seq[byte]): Future[void] =
  if state.writeFinSent:
    let fut = newFuture[void]()
    fut.fail(newException(StreamError, "write side is closed"))
    return fut
  # let stream = state.stream.valueOr:
  #   raise newException(QuicError, "stream is closed")
  # See https://github.com/status-im/nim-quic/pull/41 for more details
  state.connection.send(state.stream.get.id, bytes)

method close*(state: OpenStream) {.async.} =
  ## Close both write and read sides of the stream
  let stream = state.stream.valueOr:
    return

  # Close write side by sending FIN
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  state.writeFinSent = true

  # Close read side locally
  state.readClosed = true

  # Don't switch to ClosedStream immediately - let read() handle the transition
  # when all buffered data is consumed

method closeWrite*(state: OpenStream) {.async.} =
  ## Close write side by sending FIN, but keep read side open
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  state.writeFinSent = true
  # Note: we don't switch to ClosedStream here - read side stays open for half-close

method reset*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return

  state.closeFut.complete("stream reset")
  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state.incoming, state.frameSorter, wasReset = true))

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

method expire*(state: OpenStream) {.raises: [].} =
  let stream = state.stream.valueOr:
    return
  state.closeFut.complete("connection timed out")
  stream.closed.fire()
