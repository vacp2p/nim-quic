import ngtcp2
import ../../../helpers/[openarray, sequninit]
import ../../../errors
import ../../stream
import ../streamstate/openstate
import ./connection
import chronicles

logScope:
  topics = "native stream"

proc newStream(connection: Ngtcp2Connection, id: int64): Stream =
  let stream = newStream(id, newOpenStreamState(connection))
  connection.setStreamUserData(id, unsafeAddr stream[])
  return stream

proc openStream*(
    connection: Ngtcp2Connection, unidirectional: bool
): Stream {.raises: [QuicError].} =
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
  let stream = cast[Stream](stream_user_data)
  if stream != nil:
    try:
      stream.onClose()
    except QuicError as e:
      error "Unexpect error onStreamClose", msg = e.msg

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
  let stream = cast[Stream](stream_user_data)
  if stream != nil:
    var bytes = newSeqUninit[byte](datalen)
    copyMem(bytes.toUnsafePtr, data, datalen)
    let isFin = (flags and NGTCP2_STREAM_DATA_FLAG_FIN) != 0
    try:
      stream.onReceive(uint64(offset), bytes, isFin)
    except QuicError as e:
      error "Unexpect error onReceiveStreamData", msg = e.msg

proc onStreamReset(
    connection: ptr ngtcp2_conn,
    stream_id: int64,
    final_size: uint64,
    app_error_code: uint64,
    user_data: pointer,
    stream_user_data: pointer,
): cint {.cdecl.} =
  trace "onStreamReset"
  let stream = cast[Stream](stream_user_data)
  if stream != nil:
    try:
      stream.reset()
    except QuicError as e:
      error "Unexpect error onStreamReset", msg = e.msg

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
