import std/monotimes
import quic
import ngtcp2
import path

proc write*(connection: ptr ngtcp2_conn, datagram: var Datagram, datagramInfo: var ngtcp2_pkt_info): int =
  var offset = 0
  var length = 1
  while length > 0 and offset < datagram.len:
    length = connection.ngtcp2_conn_write_stream(
      addr zeroPath,
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

proc read*(connection: ptr ngtcp2_conn, datagram: Datagram, datagramInfo: ngtcp2_pkt_info) =
  assert 0 == connection.ngtcp2_conn_read_pkt(
    addr zeroPath,
    unsafeAddr datagramInfo,
    unsafeAddr datagram[0],
    datagram.len.uint,
    getMonoTime().ticks.uint
  )
