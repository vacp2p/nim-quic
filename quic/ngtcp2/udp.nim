import std/monotimes
import ../packets
import ../congestion
import ngtcp2
import connection
import path
import errors

proc write*(connection: Connection): Datagram =
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
  result.data = connection.buffer[0..<length]
  result.ecn = ECN(packetInfo.ecn)

proc read*(connection: Connection, datagram: DatagramBuffer, ecn = ecnNonCapable) =
  var packetInfo: ngtcp2_pkt_info
  packetInfo.ecn = ecn.uint32
  checkResult ngtcp2_conn_read_pkt(
    connection.conn,
    connection.path.toPathPtr,
    unsafeAddr packetInfo,
    unsafeAddr datagram[0],
    datagram.len.uint,
    getMonoTime().ticks.uint
  )

proc read*(connection: Connection, datagram: Datagram) =
  connection.read(datagram.data, datagram.ecn)
