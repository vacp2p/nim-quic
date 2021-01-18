import pkg/chronos
import pkg/ngtcp2
import ../../stream
import ../connection
import ../errors
import ./drainingstate
import ./closedstate

type
  OpenStream* = ref object of StreamState
    stream: Stream
    connection: Ngtcp2Connection
    incoming: AsyncQueue[seq[byte]]

proc newOpenStream*(connection: Ngtcp2Connection): OpenStream =
  OpenStream(
    connection: connection,
    incoming: newAsyncQueue[seq[byte]]()
  )

proc setUserData(state: OpenStream, userdata: pointer) =
  let conn = state.connection.conn
  let id = state.stream.id
  checkResult ngtcp2_conn_set_stream_user_data(conn, id, userdata)

proc clearUserData(state: OpenStream) =
  try:
    state.setUserData(nil)
  except Ngtcp2RecoverableError:
    discard # stream already closed

method enter(state: OpenStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = stream
  state.setUserData(unsafeAddr state[])

method leave(state: OpenStream) =
  procCall leave(StreamState(state))
  state.clearUserData()
  state.stream = nil

method read(state: OpenStream): Future[seq[byte]] {.async.} =
  result = await state.incoming.get()

method write(state: OpenStream, bytes: seq[byte]): Future[void] =
  state.connection.send(state.stream.id, bytes)

method close(state: OpenStream) {.async.} =
  let conn = state.connection.conn
  let id = state.stream.id
  checkResult ngtcp2_conn_shutdown_stream(conn, id, 0)
  state.stream.switch(newClosedStream())

proc onClose*(state: OpenStream) =
  if state.incoming.empty:
    state.stream.switch(newClosedStream())
  else:
    state.stream.switch(newDrainingStream(state.incoming))

proc receive*(state: OpenStream, bytes: seq[byte]) =
  state.incoming.putNoWait(bytes)
