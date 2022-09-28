import ../../../basics
import ../../stream
import ../native/connection
import ../native/errors
import ./drainingstate
import ./closedstate

type
  OpenStream* = ref object of StreamState
    stream: Option[Stream]
    connection: Ngtcp2Connection
    incoming: AsyncQueue[seq[byte]]

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  OpenStream(
    connection: connection,
    incoming: newAsyncQueue[seq[byte]]()
  )

proc setUserData(state: OpenStream, userdata: pointer) =
  let stream = state.stream.getOr: return
  state.connection.setStreamUserData(stream.id, userdata)

proc clearUserData(state: OpenStream) =
  try:
    state.setUserData(nil)
  except Ngtcp2Error:
    discard # stream already closed

proc allowMoreIncomingBytes(state: OpenStream, amount: uint64) =
  let stream = state.stream.get()
  state.connection.extendStreamOffset(stream.id, amount)
  state.connection.send()

{.push locks:"unknown".}

method enter(state: OpenStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = some stream
  state.setUserData(unsafeAddr state[])

method leave(state: OpenStream) =
  procCall leave(StreamState(state))
  state.clearUserData()
  state.stream = Stream.none

method read(state: OpenStream): Future[seq[byte]] {.async.} =
  result = await state.incoming.get()
  state.allowMoreIncomingBytes(result.len.uint64)

method write(state: OpenStream, bytes: seq[byte]): Future[void] =
  let stream = state.stream.getOr:
    raise newException(QuicError, "stream is closed")
  state.connection.send(stream.id, bytes)

method close(state: OpenStream) {.async.} =
  let stream = state.stream.getOr: return
  state.connection.shutdownStream(stream.id)
  stream.switch(newClosedStream())

method onClose*(state: OpenStream) =
  let stream = state.stream.getOr: return
  if state.incoming.empty:
    stream.switch(newClosedStream())
  else:
    stream.switch(newDrainingStream(state.incoming))

method isClosed*(state: OpenStream): bool =
  false

{.pop.}

proc receive*(state: OpenStream, bytes: seq[byte]) =
  state.incoming.putNoWait(bytes)
