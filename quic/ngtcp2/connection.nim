import std/sequtils
import pkg/chronos
import pkg/ngtcp2
import ../datagram
import ../stream
import ../openarray
import ../congestion
import ../timeout
import ../connectionid
import ./path
import ./errors
import ./timestamp

type
  Ngtcp2Connection* = ref Ngtcp2ConnectionObj
  Ngtcp2ConnectionObj = object
    conn*: ptr ngtcp2_conn
    path*: Path
    buffer*: array[4096, byte]
    outgoing*: AsyncQueue[Datagram]
    incoming*: AsyncQueue[Stream]
    flowing*: AsyncEvent
    handshake*: AsyncEvent
    timeout*: Timeout
    onNewId*: proc(id: ConnectionId)
    onRemoveId*: proc(id: ConnectionId)

proc destroy(connection: var Ngtcp2ConnectionObj) =
  if connection.conn != nil:
    connection.timeout.stop()
    ngtcp2_conn_del(connection.conn)
    connection.conn = nil

proc destroy*(connection: Ngtcp2Connection) =
  ## Frees any resources associated with the connection.
  connection[].destroy()

proc `=destroy`*(connection: var Ngtcp2ConnectionObj) =
  connection.destroy()

proc handleTimeout(connection: Ngtcp2Connection) {.gcsafe.}

proc newConnection*(path: Path): Ngtcp2Connection =
  let connection = Ngtcp2Connection()
  connection.path = path
  connection.outgoing = newAsyncQueue[Datagram]()
  connection.incoming = newAsyncQueue[Stream]()
  connection.flowing = newAsyncEvent()
  connection.handshake = newAsyncEvent()
  connection.timeout = newTimeout(proc = connection.handleTimeout())
  connection.flowing.fire()
  connection

proc ids*(connection: Ngtcp2Connection): seq[ConnectionId] =
  let amount = ngtcp2_conn_get_num_scid(connection.conn)
  var scids = newSeq[ngtcp2_cid](amount)
  discard ngtcp2_conn_get_scid(connection.conn, scids.toPtr)
  scids.mapIt(ConnectionId(it.data[0..<it.datalen]))

proc updateTimeout*(connection: Ngtcp2Connection) =
  let expiry = ngtcp2_conn_get_expiry(connection.conn)
  if expiry != uint64.high:
    connection.timeout.set(Moment.init(expiry.int64, 1.nanoseconds))
  else:
    connection.timeout.stop()

proc trySend(connection: Ngtcp2Connection): Datagram =
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

proc send*(connection: Ngtcp2Connection) =
  var done = false
  while not done:
    let datagram = connection.trySend()
    if datagram.data.len > 0:
      connection.outgoing.putNoWait(datagram)
    else:
      done = true
  connection.updateTimeout()

proc tryReceive(connection: Ngtcp2Connection, datagram: openArray[byte],
                ecn: ECN) =
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

proc receive*(connection: Ngtcp2Connection, datagram: openArray[byte],
              ecn = ecnNonCapable) =
  try:
    connection.tryReceive(datagram, ecn)
  except Ngtcp2RecoverableError:
    return
  connection.send()
  connection.flowing.fire()

proc receive*(connection: Ngtcp2Connection, datagram: Datagram) =
  connection.receive(datagram.data, datagram.ecn)

proc handleTimeout(connection: Ngtcp2Connection) =
  if connection.conn != nil:
    checkResult ngtcp2_conn_handle_expiry(connection.conn, now())
    connection.send()
