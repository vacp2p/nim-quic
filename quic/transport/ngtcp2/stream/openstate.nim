import ../../../basics
import ../../framesorter
import ../../stream
import ../native/connection
import ../native/errors
import ./drainingstate
import ./closedstate
import chronicles

type OpenStream* = ref object of StreamState
  stream: Opt[Stream]
  connection: Ngtcp2Connection
  incoming: AsyncQueue[seq[byte]]
  frameSorter: FrameSorter
  cancelRead: Future[void]

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  let incomingQ = newAsyncQueue[seq[byte]]()
  OpenStream(
    connection: connection,
    incoming: incomingQ,
    cancelRead: newFuture[void](),
    frameSorter: initFrameSorter(incomingQ),
  )

proc setUserData(state: OpenStream, userdata: pointer) =
  let stream = state.stream.valueOr:
    return
  state.connection.setStreamUserData(stream.id, userdata)

proc clearUserData(state: OpenStream) =
  try:
    state.setUserData(nil)
  except Ngtcp2Error:
    discard # stream already closed

proc allowMoreIncomingBytes(state: OpenStream, amount: uint64) =
  if state.stream.isSome:
    let stream = state.stream.get()
    state.connection.extendStreamOffset(stream.id, amount)
    state.connection.send()
  else:
    trace "no stream available"

{.push locks: "unknown".}

method enter(state: OpenStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = Opt.some(stream)
  state.setUserData(unsafeAddr state[])

method leave(state: OpenStream) =
  procCall leave(StreamState(state))
  state.clearUserData()
  state.stream = Opt.none(Stream)

method read(state: OpenStream): Future[seq[byte]] {.async.} =
  let incomingFut = state.incoming.get()
  if (await race(incomingFut, state.cancelRead)) == incomingFut:
    result = await incomingFut
    state.allowMoreIncomingBytes(result.len.uint64)
  else:
    incomingFut.cancelSoon()
    raise newException(StreamError, "stream is closed")

method write(state: OpenStream, bytes: seq[byte]): Future[void] =
  # let stream = state.stream.valueOr:
  #   raise newException(QuicError, "stream is closed")
  # See https://github.com/status-im/nim-quic/pull/41 for more details
  state.connection.send(state.stream.get.id, bytes)

method close(state: OpenStream) {.async.} =
  let stream = state.stream.valueOr:
    return
  state.cancelRead.cancelSoon()
  state.connection.shutdownStream(stream.id)
  stream.switch(newClosedStream())

method onClose*(state: OpenStream) =
  let stream = state.stream.valueOr:
    return
  if state.incoming.empty:
    stream.switch(newClosedStream())
  else:
    stream.switch(newDrainingStream(state.incoming))

method isClosed*(state: OpenStream): bool =
  false

{.pop.}

proc receive*(state: OpenStream, offset: uint64, bytes: seq[byte], isFin: bool) =
  state.frameSorter.insert(offset, bytes, isFin)
