import pkg/ngtcp2
import ../../../helpers/openarray
import ../../stream
import ../stream/openstate
import ./connection

proc newStream(connection: Ngtcp2Connection, id: int64): Stream =
  newStream(id, newOpenStream(connection))

proc openStream*(connection: Ngtcp2Connection, unidirectional: bool): Stream =
  var id: int64
  if unidirectional:
    id = connection.openUniStream()
  else:
    id = connection.openBidiStream()
  newStream(connection, id)

proc onStreamOpen(conn: ptr ngtcp2_conn,
                   stream_id: int64,
                   user_data: pointer): cint {.cdecl.} =
  let connection = cast[Ngtcp2Connection](user_data)
  connection.onIncomingStream(newStream(connection, stream_id))

proc onStreamClose(conn: ptr ngtcp2_conn,
                   flags: uint32,
                   stream_id: int64,
                   app_error_code: uint64,
                   user_data: pointer,
                   stream_user_data: pointer): cint {.cdecl.} =
  let openStream = cast[OpenStream](stream_user_data)
  if openStream != nil:
    openStream.onClose()

proc onReceiveStreamData(connection: ptr ngtcp2_conn,
                          flags: uint32,
                          stream_id: int64,
                          offset: uint64,
                          data: ptr uint8,
                          datalen: uint,
                          user_data: pointer,
                          stream_user_data: pointer): cint{.cdecl.} =
  let state = cast[OpenStream](stream_user_data)
  var bytes = newSeqUninitialized[byte](datalen)
  copyMem(bytes.toUnsafePtr, data, datalen)
  state.receive(bytes)

proc installStreamCallbacks*(callbacks: var ngtcp2_callbacks) =
  callbacks.stream_open = onStreamOpen
  callbacks.stream_close = onStreamClose
  callbacks.recv_stream_data = onReceiveStreamData
