import std/monotimes
import ngtcp2
import ../datagram
import connection
import errors
import path

type Stream* = object
  id: int64
  connection: Connection

proc openStream*(connection: Connection): Stream =
  checkResult ngtcp2_conn_open_uni_stream(connection.conn, addr result.id, nil)
  result.connection = connection

proc write*(stream: Stream, message: seq[byte], datagram: var Datagram) : int =
  result = ngtcp2_conn_write_stream(
    stream.connection.conn,
    stream.connection.path.toPathPtr,
    nil,
    addr datagram[0],
    datagram.len.uint,
    nil,
    0,
    stream.id,
    unsafeAddr message[0],
    message.len.uint,
    getMonoTime().ticks.uint
  )
