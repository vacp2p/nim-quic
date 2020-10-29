import std/monotimes
import ngtcp2
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

proc write*(stream: Stream, message: seq[byte]): seq[byte] =
  let length = ngtcp2_conn_write_stream(
    stream.connection.conn,
    stream.connection.path.toPathPtr,
    nil,
    addr stream.connection.buffer[0],
    stream.connection.buffer.len.uint,
    nil,
    0,
    stream.id,
    unsafeAddr message[0],
    message.len.uint,
    getMonoTime().ticks.uint
  )
  checkResult length.cint
  stream.connection.buffer[0..<length]
