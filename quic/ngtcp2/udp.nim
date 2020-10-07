import std/monotimes
import ../packets
import ngtcp2
import connection

proc write*(connection: Connection, datagram: var Datagram, datagramInfo: var ngtcp2_pkt_info): int =
  var offset = 0
  var length = 1
  while length > 0 and offset < datagram.len:
    length = ngtcp2_conn_write_stream(
      connection.conn,
      nil,
      addr datagramInfo,
      addr datagram[offset],
      (datagram.len - offset).uint,
      nil,
      NGTCP2_WRITE_STREAM_FLAG_MORE.uint32,
      -1,
      nil,
      0,
      getMonoTime().ticks.uint
    )
    offset = offset + length
  offset

proc read*(connection: Connection, datagram: Datagram, datagramInfo: ngtcp2_pkt_info) =
  assert 0 == ngtcp2_conn_read_pkt(
    connection.conn,
    unsafeAddr connection.path,
    unsafeAddr datagramInfo,
    unsafeAddr datagram[0],
    datagram.len.uint,
    getMonoTime().ticks.uint
  )
