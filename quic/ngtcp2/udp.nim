import std/monotimes
import chronos
import ngtcp2
import ../openarray
import ../packets
import ../congestion
import connection
import path
import errors

proc write*(connection: Connection) {.async.} =
  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_stream(
    connection.conn,
    connection.path.toPathPtr,
    addr packetInfo,
    addr connection.buffer[0],
    connection.buffer.len.uint,
    nil,
    0,
    -1,
    nil,
    0,
    getMonoTime().ticks.uint
  )
  let data = connection.buffer[0..<length]
  let ecn = ECN(packetInfo.ecn)
  let datagram = Datagram(data: data, ecn: ecn)
  await connection.outgoing.put(datagram)

proc read*(connection: Connection, datagram: DatagramBuffer, ecn = ecnNonCapable) =
  var packetInfo: ngtcp2_pkt_info
  packetInfo.ecn = ecn.uint32
  checkResult ngtcp2_conn_read_pkt(
    connection.conn,
    connection.path.toPathPtr,
    unsafeAddr packetInfo,
    datagram.toUnsafePtr,
    datagram.len.uint,
    getMonoTime().ticks.uint
  )

proc read*(connection: Connection, datagram: Datagram) =
  connection.read(datagram.data, datagram.ecn)
