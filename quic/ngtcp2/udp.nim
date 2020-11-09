import chronos
import ngtcp2
import ../openarray
import ../packets
import ../congestion
import connection
import path
import errors
import timestamp

proc trySend(connection: Connection): Datagram =
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
    now()
  )
  checkResult length.cint
  let data = connection.buffer[0..<length]
  let ecn = ECN(packetInfo.ecn)
  Datagram(data: data, ecn: ecn)

proc send*(connection: Connection) =
  var done = false
  while not done:
    let datagram = connection.trySend()
    if datagram.data.len > 0:
      connection.outgoing.putNoWait(datagram)
    else:
      done = true

proc receive*(connection: Connection, datagram: DatagramBuffer, ecn = ecnNonCapable) =
  var packetInfo: ngtcp2_pkt_info
  packetInfo.ecn = ecn.uint32
  checkResult ngtcp2_conn_read_pkt(
    connection.conn,
    connection.path.toPathPtr,
    unsafeAddr packetInfo,
    datagram.toUnsafePtr,
    datagram.len.uint,
    now()
  )
  connection.send()
  connection.flowing.fire()

proc receive*(connection: Connection, datagram: Datagram) =
  connection.receive(datagram.data, datagram.ecn)
