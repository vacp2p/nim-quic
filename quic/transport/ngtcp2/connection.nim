import std/sequtils
import pkg/chronos
import pkg/ngtcp2
import pkg/upraises
import pkg/questionable
import ../../udp/datagram
import ../../udp/congestion
import ../../helpers/openarray
import ../stream
import ../timeout
import ../connectionid
import ./path
import ./errors
import ./timestamp
import ./pointers
import ../../helpers/errorasdefect

type
  Ngtcp2Connection* = ref object
    conn*: ?ptr ngtcp2_conn
    path*: Path
    buffer*: array[4096, byte]
    flowing*: AsyncEvent
    timeout*: Timeout
    onSend*: proc(datagram: Datagram) {.gcsafe, upraises:[].}
    onIncomingStream*: proc(stream: Stream)
    onHandshakeDone*: proc()
    onNewId*: ?proc(id: ConnectionId)
    onRemoveId*: ?proc(id: ConnectionId)

proc destroy*(connection: Ngtcp2Connection) =
  if conn =? connection.conn:
    connection.timeout.stop()
    ngtcp2_conn_del(conn)
    connection.conn = none(ptr ngtcp2_conn)

proc handleTimeout(connection: Ngtcp2Connection) {.gcsafe, upraises:[].}

proc newConnection*(path: Path): Ngtcp2Connection =
  let connection = Ngtcp2Connection()
  connection.path = path
  connection.flowing = newAsyncEvent()
  connection.timeout = newTimeout(proc = connection.handleTimeout())
  connection.flowing.fire()
  connection

proc ids*(connection: Ngtcp2Connection): seq[ConnectionId] =
  let amount = ngtcp2_conn_get_num_scid(!connection.conn)
  var scids = newSeq[ngtcp2_cid](amount)
  discard ngtcp2_conn_get_scid(!connection.conn, scids.toPtr)
  scids.mapIt(ConnectionId(it.data[0..<it.datalen]))

proc updateTimeout*(connection: Ngtcp2Connection) =
  let expiry = ngtcp2_conn_get_expiry(!connection.conn)
  if expiry != uint64.high:
    connection.timeout.set(Moment.init(expiry.int64, 1.nanoseconds))
  else:
    connection.timeout.stop()

proc trySend(connection: Ngtcp2Connection,
             streamId: int64 = -1,
             messagePtr: ptr byte = nil,
             messageLen: uint = 0,
             written: ptr int = nil): Datagram =
  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_stream(
    !connection.conn,
    connection.path.toPathPtr,
    addr packetInfo,
    addr connection.buffer[0],
    connection.buffer.len.uint,
    written,
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

proc send*(connection: Ngtcp2Connection) =
  var done = false
  while not done:
    let datagram = connection.trySend()
    if datagram.data.len > 0:
      connection.onSend(datagram)
    else:
      done = true
  connection.updateTimeout()

proc send(connection: Ngtcp2Connection,
          streamId: int64,
          messagePtr: ptr byte,
          messageLen: uint): Future[int] {.async.} =
  let written = addr result
  var datagram = trySend(connection, streamId, messagePtr, messageLen, written)
  while datagram.data.len == 0:
    connection.flowing.clear()
    await connection.flowing.wait()
    datagram = trySend(connection, streamId, messagePtr, messageLen, written)
  connection.onSend(datagram)
  connection.updateTimeout()

proc send*(connection: Ngtcp2Connection,
           streamId: int64, bytes: seq[byte]) {.async.} =
  var messagePtr = bytes.toUnsafePtr
  var messageLen = bytes.len.uint
  var done = false
  while not done:
    let written = await connection.send(streamId, messagePtr, messageLen)
    messagePtr = messagePtr + written
    messageLen = messageLen - written.uint
    done = messageLen == 0

proc tryReceive(connection: Ngtcp2Connection, datagram: openArray[byte],
                ecn: ECN) =
  var packetInfo: ngtcp2_pkt_info
  packetInfo.ecn = ecn.uint32
  checkResult ngtcp2_conn_read_pkt(
    !connection.conn,
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
  except Ngtcp2Error:
    return
  connection.send()
  connection.flowing.fire()

proc receive*(connection: Ngtcp2Connection, datagram: Datagram) =
  connection.receive(datagram.data, datagram.ecn)

proc handleTimeout(connection: Ngtcp2Connection) =
  without conn =? connection.conn:
    return

  errorAsDefect:
    checkResult ngtcp2_conn_handle_expiry(conn, now())
    connection.send()

proc close*(connection: Ngtcp2Connection): Datagram =
  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_connection_close(
    !connection.conn,
    connection.path.toPathPtr,
    addr packetInfo,
    addr connection.buffer[0],
    connection.buffer.len.uint,
    NGTCP2_NO_ERROR,
    now()
  )
  checkResult length.cint
  let data = connection.buffer[0..<length]
  let ecn = ECN(packetInfo.ecn)
  Datagram(data: data, ecn: ecn)

proc closingDuration*(connection: Ngtcp2Connection): Duration =
  3 * ngtcp2_conn_get_pto(!connection.conn).int64.nanoseconds

proc isDraining*(connection: Ngtcp2Connection): bool =
  ngtcp2_conn_is_in_draining_period(!connection.conn).bool
