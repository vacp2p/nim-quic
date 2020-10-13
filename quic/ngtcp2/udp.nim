import std/monotimes
import ../packets
import ../congestion
import ngtcp2
import connection
import path
import errors

proc write*(connection: Connection, datagram: var Datagram, ecn: var ECN): int =
  var offset = 0
  var length = 1
  while length > 0 and offset < datagram.len:
    var packetInfo: ngtcp2_pkt_info
    length = ngtcp2_conn_write_stream(
      connection.conn,
      nil,
      addr packetInfo,
      addr datagram[offset],
      (datagram.len - offset).uint,
      nil,
      NGTCP2_WRITE_STREAM_FLAG_MORE.uint32,
      -1,
      nil,
      0,
      getMonoTime().ticks.uint
    )
    ecn = ECN(packetInfo.ecn)
    offset = offset + length
  offset

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
