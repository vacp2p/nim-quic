import std/sequtils
import pkg/chronos
import pkg/ngtcp2
import pkg/upraises
import pkg/questionable
import ../../../errors
import ../../../udp/datagram
import ../../../udp/congestion
import ../../../helpers/openarray
import ../../stream
import ../../timeout
import ../../connectionid
import ./path
import ./errors as ngtcp2errors
import ./timestamp
import ./pointers

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
  Ngtcp2ConnectionClosed* = object of QuicError

proc destroy*(connection: Ngtcp2Connection) =
  if conn =? connection.conn:
    connection.timeout.stop()
    ngtcp2_conn_del(conn)
    connection.conn = none(ptr ngtcp2_conn)
    connection.onSend = nil
    connection.onIncomingStream = nil
    connection.onHandshakeDone = nil
    connection.onNewId = none proc(id: ConnectionId)
    connection.onRemoveId = none proc(id: ConnectionId)

proc handleTimeout(connection: Ngtcp2Connection) {.gcsafe, upraises:[].}

proc newConnection*(path: Path): Ngtcp2Connection =
  let connection = Ngtcp2Connection()
  connection.path = path
  connection.flowing = newAsyncEvent()
  connection.timeout = newTimeout(proc = connection.handleTimeout())
  connection.flowing.fire()
  connection

proc ids*(connection: Ngtcp2Connection): seq[ConnectionId] =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  let amount = ngtcp2_conn_get_num_scid(conn)
  var scids = newSeq[ngtcp2_cid](amount)
  discard ngtcp2_conn_get_scid(conn, scids.toPtr)
  scids.mapIt(ConnectionId(it.data[0..<it.datalen]))

proc updateTimeout*(connection: Ngtcp2Connection) =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  let expiry = ngtcp2_conn_get_expiry(conn)
  if expiry != uint64.high:
    connection.timeout.set(Moment.init(expiry.int64, 1.nanoseconds))
  else:
    connection.timeout.stop()

proc trySend(connection: Ngtcp2Connection,
             streamId: int64 = -1,
             messagePtr: ptr byte = nil,
             messageLen: uint = 0,
             written: ptr int = nil): Datagram =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_stream(
    conn,
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
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  var packetInfo: ngtcp2_pkt_info
  packetInfo.ecn = ecn.uint32
  checkResult ngtcp2_conn_read_pkt(
    conn,
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
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_connection_close(
    conn,
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
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  3 * ngtcp2_conn_get_pto(conn).int64.nanoseconds

proc isDraining*(connection: Ngtcp2Connection): bool =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  ngtcp2_conn_is_in_draining_period(conn).bool

proc isHandshakeCompleted*(connection: Ngtcp2Connection): bool =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  ngtcp2_conn_get_handshake_completed(conn).bool

proc openUniStream*(connection: Ngtcp2Connection): int64 =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult ngtcp2_conn_open_uni_stream(conn, addr result, nil)

proc setStreamUserData*(connection: Ngtcp2Connection,
                        streamId: int64,
                        userdata: pointer) =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult ngtcp2_conn_set_stream_user_data(conn, streamId, userdata)

proc extendStreamOffset*(connection: Ngtcp2Connection,
                         streamId: int64,
                         amount: uint64) =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult conn.ngtcp2_conn_extend_max_stream_offset(streamId, amount)
  conn.ngtcp2_conn_extend_max_offset(amount)

proc shutdownStream*(connection: Ngtcp2Connection, streamId: int64) =
  without conn =? connection.conn:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult ngtcp2_conn_shutdown_stream(conn, streamId, 0)
