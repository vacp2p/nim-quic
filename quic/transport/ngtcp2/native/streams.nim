import ngtcp2
import ../../../helpers/openarray
import ../../stream
import ../streamstate/openstate
import ./connection
import chronicles

proc newStream(connection: Ngtcp2Connection, id: int64): Stream =
  newStream(id, newOpenStreamState(connection))

proc openStream*(connection: Ngtcp2Connection, unidirectional: bool): Stream =
  var id: int64
  if unidirectional:
    id = connection.openUniStream()
  else:
    id = connection.openBidiStream()
  newStream(connection, id)

proc onStreamOpen(
    conn: ptr ngtcp2_conn, stream_id: int64, user_data: pointer
): cint {.cdecl.} =
  let connection = cast[Ngtcp2Connection](user_data)
  connection.onIncomingStream(newStream(connection, stream_id))

proc onStreamClose(
    conn: ptr ngtcp2_conn,
    flags: uint32,
    stream_id: int64,
    app_error_code: uint64,
    user_data: pointer,
    stream_user_data: pointer,
): cint {.cdecl.} =
  trace "onStreamClose"
  let state = cast[StreamState](stream_user_data)
  if state != nil:
    state.onClose()

proc onReceiveStreamData(
    connection: ptr ngtcp2_conn,
    flags: uint32,
    stream_id: int64,
    offset: uint64,
    data: ptr uint8,
    datalen: csize_t,
    user_data: pointer,
    stream_user_data: pointer,
): cint {.cdecl.} =
  trace "onReceiveStreamData"
  let state = cast[StreamState](stream_user_data)
  var bytes = newSeqUninitialized[byte](datalen)
  copyMem(bytes.toUnsafePtr, data, datalen)
  let isFin = (flags and NGTCP2_STREAM_DATA_FLAG_FIN) != 0
  if state != nil:
    state.receive(uint64(offset), bytes, isFin)

proc onStreamReset(
    connection: ptr ngtcp2_conn,
    stream_id: int64,
    final_size: uint64,
    app_error_code: uint64,
    user_data: pointer,
    stream_user_data: pointer,
): cint {.cdecl.} =
  trace "onStreamReset"
  let state = cast[StreamState](stream_user_data)
  if state != nil:
    state.reset()

proc onStreamStopSending(
    conn: ptr ngtcp2_conn,
    stream_id: int64,
    app_error_code: uint64,
    user_data: pointer,
    stream_user_data: pointer,
): cint {.cdecl.} =
  trace "onStreamStopSending"
  return 0

proc installStreamCallbacks*(callbacks: var ngtcp2_callbacks) =
  callbacks.stream_open = onStreamOpen
  callbacks.stream_close = onStreamClose
  callbacks.recv_stream_data = onReceiveStreamData
  callbacks.stream_reset = onStreamReset
  callbacks.stream_stop_sending = onStreamStopSending
