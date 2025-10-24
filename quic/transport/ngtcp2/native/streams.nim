import ngtcp2
import ../../../helpers/[openarray, sequninit]
import ../../../errors
import ../../stream
import ../streamstate/openstate
import ./connection
import chronicles

logScope:
  topics = "native stream"

proc openStream*(
    connection: Ngtcp2Connection, unidirectional: bool
): Stream {.raises: [QuicError].} =
  let stream = newStream()
  stream.switch(newOpenStreamState(connection, stream))
  let id =
    if unidirectional:
      connection.openUniStream(addr stream[])
    else:
      connection.openBidiStream(addr stream[])
  stream.id = id
  return stream

proc onStreamOpen(
    conn: ptr ngtcp2_conn, stream_id: int64, user_data: pointer
): cint {.cdecl.} =
  let connection = cast[Ngtcp2Connection](user_data)
  let stream = newStream()
  stream.switch(newOpenStreamState(connection, stream))
  stream.id = stream_id
  connection.setStreamUserData(stream_id, addr stream[])
  connection.onIncomingStream(stream)

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

proc onAckedStreamDataOffset(
    conn: ptr ngtcp2_conn,
    stream_id: int64,
    offset: uint64,
    datalen: uint64,
    user_data: pointer,
    stream_user_data: pointer,
): cint {.cdecl.} =
  trace "onAckedStreamDataOffset"
  let connection = cast[Ngtcp2Connection](user_data)
  connection.ackSentBytes(stream_id, offset, datalen)
  return 0

proc onExtendMaxStreamData(
    conn: ptr ngtcp2_conn,
    stream_id: int64,
    max_data: uint64,
    user_data: pointer,
    stream_user_data: pointer,
): cint {.cdecl.} =
  trace "onExtendMaxStreamData"
  let connection = cast[Ngtcp2Connection](user_data)
  connection.extendMaxStreamData(stream_id)

proc installStreamCallbacks*(callbacks: var ngtcp2_callbacks) =
  callbacks.stream_open = onStreamOpen
  callbacks.stream_close = onStreamClose
  callbacks.recv_stream_data = onReceiveStreamData
  callbacks.stream_reset = onStreamReset
  callbacks.stream_stop_sending = onStreamStopSending
  callbacks.acked_stream_data_offset = onAckedStreamDataOffset
  callbacks.extend_max_stream_data = onExtendMaxStreamData
