import pkg/chronos
import pkg/ngtcp2
import ../../../helpers/openarray
import ../../stream
import ../connection
import ../errors
import ../pointers
import ./sending
import ./state
import ./closedstate

type
  OpenStream* = ref object of StreamState
    id: int64
    connection: Ngtcp2Connection
    incoming: AsyncQueue[seq[byte]]

proc read(stream: Stream, state: OpenStream): Future[seq[byte]] {.async.} =
  result = await state.incoming.get()

proc write(stream: Stream, state: OpenStream, bytes: seq[byte]) {.async.} =
  let connection = state.connection
  let streamId = state.id
  var messagePtr = bytes.toUnsafePtr
  var messageLen = bytes.len.uint
  var done = false
  while not done:
    let written = await send(connection, streamId, messagePtr, messageLen)
    messagePtr = messagePtr + written
    messageLen = messageLen - written.uint
    done = messageLen == 0

proc close(stream: Stream, state: OpenStream) {.async.} =
  checkResult ngtcp2_conn_shutdown_stream(state.connection.conn, state.id, 0)
  stream.switch(newClosedState())

proc destroy(state: OpenStream) =
  let conn = state.connection.conn
  let id = state.id
  checkResult ngtcp2_conn_set_stream_user_data(conn, id, nil)

proc setUserData(state: OpenStream) =
  let conn = state.connection.conn
  let id = state.id
  let userdata = unsafeAddr state[]
  checkResult ngtcp2_conn_set_stream_user_data(conn, id, userdata)

proc newOpenState*(connection: Ngtcp2Connection, id: int64): OpenStream =
  let state = newState[OpenStream]()
  state.connection = connection
  state.id = id
  state.incoming = newAsyncQueue[seq[byte]]()
  state.setUserData()
  state

proc receive*(state: OpenStream, bytes: seq[byte]) =
  state.incoming.putNoWait(bytes)
