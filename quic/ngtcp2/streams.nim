import chronos
import ngtcp2
import ../openarray
import ../datagram
import ../congestion
import connection
import errors
import path
import pointers
import timestamp

proc openStream*(connection: Connection): Stream =
  var id: int64
  checkResult ngtcp2_conn_open_uni_stream(connection.conn, addr id, nil)
  result = newStream(connection, id)
  checkResult ngtcp2_conn_set_stream_user_data(connection.conn, id, addr result)

proc close*(stream: Stream) =
  checkResult ngtcp2_conn_shutdown_stream(stream.connection.conn, stream.id, 0)

proc trySend(stream: Stream, messagePtr: ptr byte, messageLen: uint, written: var int): Datagram =
  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_stream(
    stream.connection.conn,
    stream.connection.path.toPathPtr,
    addr packetInfo,
    addr stream.connection.buffer[0],
    stream.connection.buffer.len.uint,
    addr written,
    0,
    stream.id,
    messagePtr,
    messageLen,
    now()
  )
  checkResult length.cint
  let data = stream.connection.buffer[0..<length]
  let ecn = ECN(packetInfo.ecn)
  Datagram(data: data, ecn: ecn)

proc send(stream: Stream, messagePtr: ptr byte, messageLen: uint): Future[int] {.async.} =
  var datagram = stream.trySend(messagePtr, messageLen, result)
  while datagram.data.len == 0:
    stream.connection.flowing.clear()
    await stream.connection.flowing.wait()
    datagram = stream.trySend(messagePtr, messageLen, result)
  await stream.connection.outgoing.put(datagram)

proc write*(stream: Stream, message: seq[byte]) {.async.} =
  var messagePtr = message.toUnsafePtr
  var messageLen = message.len.uint
  var done = false
  while not done:
    let written = await stream.send(messagePtr, messageLen)
    messagePtr = messagePtr + written
    messageLen = messageLen - written.uint
    done = messageLen == 0

proc streamOpen*(conn: ptr ngtcp2_conn, stream_id: int64; user_data: pointer): cint {.cdecl.} =
  let connection = cast[Connection](user_data)
  connection.incoming.putNoWait(newStream(connection, stream_id))

proc incomingStream*(connection: Connection): Future[Stream] {.async.} =
  result = await connection.incoming.get()

proc receiveStreamData*(connection: ptr ngtcp2_conn, flags: uint32, stream_id: int64, offset: uint64, data: ptr uint8, datalen: uint, user_data: pointer, stream_user_data: pointer): cint{.cdecl.} =
  let stream = cast[Stream](stream_user_data)
  var bytes = newSeqUninitialized[byte](datalen)
  copyMem(bytes.toUnsafePtr, data, datalen)
  stream.incoming.putNoWait(bytes)
  checkResult connection.ngtcp2_conn_extend_max_stream_offset(stream_id, datalen)
  connection.ngtcp2_conn_extend_max_offset(datalen)

proc read*(stream: Stream): Future[seq[byte]] {.async.} =
  result = await stream.incoming.get()
