import pkg/chronos
import pkg/ngtcp2
import ../../helpers/openarray
import ../stream
import ./connection
import ./errors
import ./stream/openstate

proc newStream*(connection: Ngtcp2Connection, id: int64): Stream =
  newStream(id, newOpenStream(connection, id))

proc openStream*(connection: Ngtcp2Connection): Stream =
  var id: int64
  checkResult ngtcp2_conn_open_uni_stream(connection.conn, addr id, nil)
  newStream(connection, id)

proc incomingStream*(connection: Ngtcp2Connection): Future[Stream] {.async.} =
  result = await connection.incoming.get()

proc onStreamOpen(conn: ptr ngtcp2_conn,
                   stream_id: int64,
                   user_data: pointer): cint {.cdecl.} =
  let connection = cast[Ngtcp2Connection](user_data)
  connection.incoming.putNoWait(newStream(connection, stream_id))

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
  checkResult:
    connection.ngtcp2_conn_extend_max_stream_offset(stream_id, datalen)
  connection.ngtcp2_conn_extend_max_offset(datalen)

proc installStreamCallbacks*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.stream_open = onStreamOpen
  callbacks.recv_stream_data = onReceiveStreamData
