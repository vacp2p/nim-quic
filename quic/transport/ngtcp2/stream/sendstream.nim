import ../../../basics
import ../../stream
import ../../framesorter
import ../native/connection
import ./closestream
import ./helpers
import ./errors

type SendStream* = ref object of StreamState
  stream*: Opt[Stream]
  connection*: Ngtcp2Connection
  incoming: AsyncQueue[seq[byte]]
  frameSorter: FrameSorter

proc newSendStream*(
    connection: Ngtcp2Connection,
    incoming: AsyncQueue[seq[byte]],
    frameSorter: FrameSorter,
): SendStream =
  SendStream(connection: connection, incoming: incoming, frameSorter: frameSorter)

method enter*(state: SendStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  setUserData(state.stream, state.connection, unsafeAddr state[])

method leave*(state: SendStream) =
  setUserData(state.stream, state.connection, nil)
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: SendStream): Future[seq[byte]] {.async.} =
  raise newException(ClosedStreamError, "read side is closed")

method write*(state: SendStream, bytes: seq[byte]) {.async.} =
  await state.connection.send(state.stream.get.id, bytes)

method close*(state: SendStream) {.async.} =
  discard

method closeWrite*(state: SendStream) {.async.} =
  ## Close write side by sending FIN, but keep read side open
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true) # Send FIN
  stream.switch(newClosedStream(state.incoming, state.frameSorter))

proc closeRead*(stream: SendStream) {.async.} =
  discard

method onClose*(state: SendStream) =
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

method isClosed*(state: SendStream): bool =
  false

method receive*(state: SendStream, offset: uint64, bytes: seq[byte], isFin: bool) =
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

method reset*(state: SendStream) =
  let stream = state.stream.valueOr:
    return

  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state.incoming, state.frameSorter, wasReset = true))

method expire*(state: SendStream) {.raises: [].} =
  expire(state.stream)
