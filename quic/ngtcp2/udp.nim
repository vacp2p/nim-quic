import std/monotimes
import ../packets
import ../congestion
import ngtcp2
import connection
import path
import errors

proc write*(connection: Connection, datagram: var Datagram, ecn: var ECN): int =
  var packetInfo: ngtcp2_pkt_info
  result = ngtcp2_conn_write_stream(
    connection.conn,
    connection.path.toPathPtr,
    addr packetInfo,
    addr datagram[0],
    datagram.len.uint,
    nil,
    0,
    -1,
    nil,
    0,
    getMonoTime().ticks.uint
  )
  ecn = ECN(packetInfo.ecn)

proc write*(connection: Connection, datagram: var Datagram): int =
  var ecn: ECN
  write(connection, datagram, ecn)

proc read*(connection: Connection, datagram: Datagram, ecn = ecnNonCapable) =
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
