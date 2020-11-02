import std/monotimes
import chronos
import ngtcp2
import ../openarray
import ../datagram
import ../congestion
import connection
import errors
import path

type Stream* = object
  id: int64
  connection: Connection

proc openStream*(connection: Connection): Stream =
  checkResult ngtcp2_conn_open_uni_stream(connection.conn, addr result.id, nil)
  result.connection = connection

proc close*(stream: Stream) =
  checkResult ngtcp2_conn_shutdown_stream(stream.connection.conn, stream.id, 0)

proc write*(stream: Stream, message: seq[byte]) {.async.} =
  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_stream(
    stream.connection.conn,
    stream.connection.path.toPathPtr,
    addr packetInfo,
    addr stream.connection.buffer[0],
    stream.connection.buffer.len.uint,
    nil,
    0,
    stream.id,
    message.toUnsafePtr,
    message.len.uint,
    getMonoTime().ticks.uint
  )
  checkResult length.cint
  let data = stream.connection.buffer[0..<length]
  let ecn = ECN(packetInfo.ecn)
  let datagram = Datagram(data: data, ecn: ecn)
  await stream.connection.outgoing.put(datagram)
