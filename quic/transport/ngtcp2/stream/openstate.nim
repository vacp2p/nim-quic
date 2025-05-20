import ../../../basics
import ../../framesorter
import ../../stream
import ../../timeout
import ./helpers
import ../native/[connection, errors]
import ./closedstate
import chronicles

type OpenStream* = ref object of StreamState
  stream*: Opt[Stream]
  incoming*: AsyncQueue[seq[byte]]
  connection*: Ngtcp2Connection
  frameSorter*: FrameSorter
  cancelRead*: Future[void]

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  let incomingQ = newAsyncQueue[seq[byte]]()
  OpenStream(
    connection: connection,
    incoming: incomingQ,
    cancelRead: newFuture[void](),
    frameSorter: initFrameSorter(incomingQ),
  )

method enter*(state: OpenStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  setUserData(state.stream, state.connection, unsafeAddr state[])

method leave*(state: OpenStream) =
  procCall leave(StreamState(state))
  state.stream = Opt.none(Stream)

method read*(state: OpenStream): Future[seq[byte]] {.async.} =
  let incomingFut = state.incoming.get()
  let timeoutFut = state.connection.timeout.expired()
  let raceFut = await race(incomingFut, state.cancelRead, timeoutFut)
  if (await race(incomingFut, state.cancelRead)) == incomingFut:
    result = await incomingFut
    allowMoreIncomingBytes(state.stream, state.connection, result.len.uint64)
  else:
    incomingFut.cancelSoon()
    let stream = state.stream.valueOr:
      return
    if state.frameSorter.isEOF():
      stream.switch(
        newClosedStream(state.incoming, state.frameSorter, state.connection)
      )

    raise
      if raceFut == timeoutFut:
        newException(StreamError, "stream timed out")
      else:
        newException(StreamError, "stream is closed")

method write*(state: OpenStream, bytes: seq[byte]): Future[void] =
  # let stream = state.stream.valueOr:
  #   raise newException(QuicError, "stream is closed")
  # See https://github.com/status-im/nim-quic/pull/41 for more details
  state.connection.send(state.stream.get.id, bytes)

method close*(state: OpenStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  discard state.connection.send(state.stream.get.id, @[], true)
  stream.switch(newClosedStream(state.incoming, state.frameSorter, state.connection))

method reset*(state: OpenStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  state.cancelRead.cancelSoon()
  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
  state.frameSorter.reset()
  stream.switch(newClosedStream(state.incoming, state.frameSorter, state.connection))

method onClose*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return
  stream.switch(newClosedStream(state.incoming, state.frameSorter, state.connection))

method isClosed*(state: OpenStream): bool =
  false

method receive*(state: OpenStream, offset: uint64, bytes: seq[byte], isFin: bool) =
  let stream = state.stream.valueOr:
    return

  state.frameSorter.insert(offset, bytes, isFin)

  if state.frameSorter.isComplete():
    stream.closed.fire()
    stream.switch(newClosedStream(state.incoming, state.frameSorter, state.connection))
