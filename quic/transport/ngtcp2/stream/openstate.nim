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

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  let incomingQ = newAsyncQueue[seq[byte]]()
  OpenStream(
    connection: connection,
    incoming: incomingQ,
    closeFut: newFuture[string](),
    frameSorter: initFrameSorter(incomingQ),
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
  let incomingFut = state.incoming.get()
  let raceFut = await race(state.closeFut, incomingFut)
  if raceFut == incomingFut:
    result = await incomingFut
    allowMoreIncomingBytes(state.stream, state.connection, result.len.uint64)
  else:
    incomingFut.cancelSoon()
    let stream = state.stream.valueOr:
      return
    if state.frameSorter.isEOF():
      stream.switch(newClosedStream(state.incoming, state.frameSorter))

    let closeReason = await state.closeFut
    raise newException(StreamError, closeReason)

method write*(state: OpenStream, bytes: seq[byte]): Future[void] =
  # let stream = state.stream.valueOr:
  #   raise newException(QuicError, "stream is closed")
  # See https://github.com/status-im/nim-quic/pull/41 for more details
  state.connection.send(state.stream.get.id, bytes)

method close*(state: OpenStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true)
  stream.switch(newClosedStream(state.incoming, state.frameSorter))

method reset*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return

  state.closeFut.complete("stream reset")
  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state.incoming, state.frameSorter))

method onClose*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return
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

method expire*(state: OpenStream) {.raises: [].} =
  let stream = state.stream.valueOr:
    return
  state.closeFut.complete("connection timed out")
  stream.closed.fire()
