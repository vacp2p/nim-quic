import std/monotimes
import chronos
import ngtcp2
import ../openarray
import ../datagram
import ../congestion
import connection
import errors
import path
import pointers

type Stream* = object
  id: int64
  connection: Connection

proc openStream*(connection: Connection): Stream =
  checkResult ngtcp2_conn_open_uni_stream(connection.conn, addr result.id, nil)
  result.connection = connection

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
    getMonoTime().ticks.uint
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

proc receiveStreamData*(connection: ptr ngtcp2_conn, flags: uint32, stream_id: int64, offset: uint64, data: ptr uint8, datalen: uint, user_data: pointer, stream_user_data: pointer): cint{.cdecl.} =
  checkResult connection.ngtcp2_conn_extend_max_stream_offset(stream_id, datalen)
  connection.ngtcp2_conn_extend_max_offset(datalen)
