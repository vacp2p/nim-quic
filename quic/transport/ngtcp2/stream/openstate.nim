import pkg/chronos
import pkg/questionable
import ../../stream
import ../native/connection
import ../native/errors
import ./drainingstate
import ./closedstate

type
  OpenStream* = ref object of StreamState
    stream: ?Stream
    connection: Ngtcp2Connection
    incoming: AsyncQueue[seq[byte]]

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  OpenStream(
    connection: connection,
    incoming: newAsyncQueue[seq[byte]]()
  )

proc setUserData(state: OpenStream, userdata: pointer) =
  let id = (!state.stream).id
  state.connection.setStreamUserData(id, userdata)

proc clearUserData(state: OpenStream) =
  try:
    state.setUserData(nil)
  except Ngtcp2Error:
    discard # stream already closed

proc allowMoreIncomingBytes(state: OpenStream, amount: uint64) =
  let stream = !state.stream
  state.connection.extendStreamOffset(stream.id, amount)
  state.connection.send()

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
  state.connection.send((!state.stream).id, bytes)

method close(state: OpenStream) {.async.} =
  let stream = (!state.stream)
  state.connection.shutdownStream(stream.id)
  stream.switch(newClosedStream())

proc onClose*(state: OpenStream) =
  if state.incoming.empty:
    (!state.stream).switch(newClosedStream())
  else:
    (!state.stream).switch(newDrainingStream(state.incoming))

proc receive*(state: OpenStream, bytes: seq[byte]) =
  state.incoming.putNoWait(bytes)
