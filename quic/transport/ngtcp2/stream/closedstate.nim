import ../../../basics
import ../../stream
import ./helpers
import ../../framesorter
import ../native/[connection, errors]
import chronicles

logScope:
  topics = "closed state"

type
  ClosedStream* = ref object of StreamState
    stream*: Opt[Stream]
    remaining: AsyncQueue[seq[byte]]
    connection*: Ngtcp2Connection
    frameSorter: FrameSorter
    cancelRead*: Future[void]

  ClosedStreamError* = object of StreamError

proc newClosedStream*(
    messages: AsyncQueue[seq[byte]],
    frameSorter: FrameSorter,
    connection: Ngtcp2Connection,
): ClosedStream =
  ClosedStream(
    remaining: messages,
    cancelRead: newFuture[void](),
    frameSorter: frameSorter,
    connection: connection,
  )

method enter(state: ClosedStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)

proc clearUserData*(state: ClosedStream) =
  try:
    setUserData(state.stream, state.connection, nil)
  except Ngtcp2Error:
    discard # stream already closed

method leave(state: ClosedStream) =
  state.stream = Opt.none(Stream)

method read(state: ClosedStream): Future[seq[byte]] {.async.} =
  if not state.frameSorter.isComplete():
    let incomingFut = state.remaining.get()
    if (await race(incomingFut, state.cancelRead)) == incomingFut:
      result = await incomingFut
      allowMoreIncomingBytes(state.stream, state.connection, result.len.uint64)
    else:
      incomingFut.cancelSoon()
      raise newException(StreamError, "stream is closed")
  else:
    try:
      result = state.remaining.popFirstNoWait()
      return
    except AsyncQueueEmptyError:
      discard

    raise newException(StreamError, "stream is closed")

method write(state: ClosedStream, bytes: seq[byte]) {.async.} =
  trace "cant write, stream is closed"
  raise newException(ClosedStreamError, "stream is closed")

method close(state: ClosedStream) {.async.} =
  discard

method onClose(state: ClosedStream) =
  discard

method isClosed(state: ClosedStream): bool =
  true

method receive(state: ClosedStream, offset: uint64, bytes: seq[byte], isFin: bool) =
  if state.frameSorter.isComplete():
    return

  state.frameSorter.insert(offset, bytes, isFin)

  if state.frameSorter.isComplete():
    state.clearUserData()

  if state.stream.isSome:
    let stream = state.stream.get()
    stream.closed.fire()

method reset(state: ClosedStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  state.cancelRead.cancelSoon()
  state.connection.shutdownStream(stream.id)
  stream.closed.fire()
