import pkg/chronos
import pkg/ngtcp2
import ../../../udp/datagram
import ../../../udp/congestion
import ../connection
import ../path
import ../errors
import ../timestamp

proc trySend(connection: Ngtcp2Connection,
             streamId: int64,
             messagePtr: ptr byte,
             messageLen: uint,
             written: var int): Datagram =
  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_stream(
    connection.conn,
    connection.path.toPathPtr,
    addr packetInfo,
    addr connection.buffer[0],
    connection.buffer.len.uint,
    addr written,
    0,
    streamId,
    messagePtr,
    messageLen,
    now()
  )
  checkResult length.cint
  let data = connection.buffer[0..<length]
  let ecn = ECN(packetInfo.ecn)
  Datagram(data: data, ecn: ecn)

proc send*(connection: Ngtcp2Connection,
           streamId: int64,
           messagePtr: ptr byte,
           messageLen: uint): Future[int] {.async.} =
  var datagram = trySend(connection, streamId, messagePtr, messageLen, result)
  while datagram.data.len == 0:
    connection.flowing.clear()
    await connection.flowing.wait()
    datagram = trySend(connection, streamId, messagePtr, messageLen, result)
  await connection.outgoing.put(datagram)
  connection.updateTimeout()
