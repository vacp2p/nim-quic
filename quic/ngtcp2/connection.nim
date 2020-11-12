import chronos
import ngtcp2
import ../datagram
import ../openarray
import ../congestion
import path
import errors
import timestamp

type
  Connection* = ref ConnectionObj
  ConnectionObj = object
    conn*: ptr ngtcp2_conn
    path*: Path
    buffer*: array[4096, byte]
    outgoing*: AsyncQueue[Datagram]
    incoming*: AsyncQueue[Stream]
    flowing*: AsyncEvent
    handshake*: AsyncEvent
  Stream* = ref object
    id*: int64
    connection*: Connection
    incoming*: AsyncQueue[seq[byte]]

proc `=destroy`*(connection: var ConnectionObj) =
  if connection.conn != nil:
    ngtcp2_conn_del(connection.conn)
    connection.conn = nil

proc newConnection*(path: Path): Connection =
  new result
  result.path = path
  result.outgoing = newAsyncQueue[Datagram]()
  result.incoming = newAsyncQueue[Stream]()
  result.flowing = newAsyncEvent()
  result.handshake = newAsyncEvent()
  result.flowing.fire()

proc newStream*(connection: Connection, id: int64): Stream =
  new result
  result.connection = connection
  result.id = id
  result.incoming = newAsyncQueue[seq[byte]]()
  checkResult ngtcp2_conn_set_stream_user_data(connection.conn, id, addr result[])

proc trySend(connection: Connection): Datagram =
  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_pkt(
    connection.conn,
    connection.path.toPathPtr,
    addr packetInfo,
    addr connection.buffer[0],
    connection.buffer.len.uint,
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
