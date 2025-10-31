import std/[sequtils, tables]
import ngtcp2
import bearssl/rand
import chronicles
import ../../../basics
import ../../../udp/congestion
import ../../../helpers/[openarray, sequninit]
import ../../timeout
import ../../connectionid
import ./path
import ./errors as ngtcp2errors
import ./timestamp
import ./pointers
import ./types
import ./certificates
import ./pendingackqueue

logScope:
  topics = "ngtcp2 conn"

const writeBufferSize* = 4096

export Ngtcp2Connection

proc destroy*(connection: Ngtcp2Connection) =
  let conn = connection.conn.valueOr:
    return

  for blockedFut in connection.blockedStreams.values():
    blockedFut.cancelSoon()

  connection.expiryTimer.stop()
  ngtcp2_conn_del(conn)
  dealloc(connection.connref)
  SSL_free(connection.ssl)
  connection.ssl = nil
  connection.connref = nil
  connection.conn = Opt.none(ptr ngtcp2_conn)
  connection.onSend = nil
  connection.onIncomingStream = nil
  connection.onHandshakeDone = nil
  connection.onNewId = Opt.none(proc(id: ConnectionId))
  connection.onRemoveId = Opt.none(proc(id: ConnectionId))

proc handleTimeout(connection: Ngtcp2Connection) {.gcsafe, raises: [].}

proc newConnection*(path: Path, rng: ref HmacDrbgContext): Ngtcp2Connection =
  let connection = Ngtcp2Connection()
  connection.rng = rng
  connection.path = path
  connection.flowing = newAsyncEvent()
  connection.expiryTimer = newTimeout(
    proc() =
      connection.handleTimeout()
  )
  connection.flowing.fire()

  connection

proc ids*(connection: Ngtcp2Connection): seq[ConnectionId] =
  let
    conn = connection.conn.valueOr:
      return
    amount = ngtcp2_conn_get_scid(conn, nil)
  var scids = newSeq[ngtcp2_cid](amount)
  discard ngtcp2_conn_get_scid(conn, scids.toPtr)
  scids.mapIt(ConnectionId(it.data[0 ..< it.datalen]))

proc updateExpiryTimer*(connection: Ngtcp2Connection) =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")
  trace "updateTimeout"
  let expiry = ngtcp2_conn_get_expiry(conn)
  if expiry != uint64.high:
    connection.expiryTimer.set(Moment.init(expiry.int64, 1.nanoseconds))
  else:
    connection.expiryTimer.stop()

proc waitUntilUnblocked(
    connection: Ngtcp2Connection, streamId: int64
) {.async: (raises: [CancelledError]).} =
  if not connection.blockedStreams.hasKey(streamId):
    return
  try:
    await connection.blockedStreams[streamId]
  except KeyError:
    raiseAssert "checked with hasKey"

proc extendMaxStreamData*(connection: Ngtcp2Connection, streamId: int64) =
  ## Unblocks any stream that might have been blocked due to flow control
  try:
    if connection.blockedStreams.hasKey(streamId):
      connection.blockedStreams[streamId].complete()
      connection.blockedStreams.del(streamId)
  except KeyError:
    raiseAssert "checked with hasKey"

proc trySend(
    connection: Ngtcp2Connection,
    buffer: var seq[byte],
    streamId: int64 = -1,
    messagePtr: ptr byte = nil,
    messageLen: uint = 0,
    written: ptr int = nil,
    isFin: bool = false,
): Datagram =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  let flags = if isFin: NGTCP2_WRITE_STREAM_FLAG_FIN else: NGTCP2_WRITE_STREAM_FLAG_NONE

  var packetInfo: ngtcp2_pkt_info
  let length = ngtcp2_conn_write_stream_versioned(
    conn,
    connection.path.toPathPtr,
    NGTCP2_PKT_INFO_V1,
    addr packetInfo,
    addr buffer[0],
    buffer.len.uint,
    cast[ptr ngtcp2_ssize](written),
    flags,
    streamId,
    messagePtr,
    messageLen,
    now(),
  )

  if length.int == NGTCP2_ERR_STREAM_DATA_BLOCKED:
    if not connection.blockedStreams.hasKey(streamId):
      connection.blockedStreams[streamId] =
        Future[void].Raising([CancelledError]).init("StreamLatch")
    return Datagram()

  checkResult length.cint

  if length == 0:
    # if nothing was written to buffer we should return empty datagram
    # without using buffer for data because nothing was written and 
    # we should not waste this buffer, by setting length to 0, because buffer
    # can be used for next trySend call.
    return Datagram()

  buffer.setLen(length)
  return Datagram(data: buffer, ecn: ECN(packetInfo.ecn))

proc send*(connection: Ngtcp2Connection) {.raises: [QuicError].} =
  ## Send control flow messages
  while true:
    var buffer = newSeqUninit[byte](writeBufferSize)
    let datagram = connection.trySend(buffer)
    if datagram.data.len == 0:
      break
    connection.onSend(datagram)
  connection.updateExpiryTimer()

proc send(
    connection: Ngtcp2Connection,
    streamId: int64,
    messagePtr: ptr byte,
    messageLen: uint,
    isFin: bool = false,
): Future[int] {.async: (raises: [CancelledError, QuicError]).} =
  if messageLen == 0 and not isFin:
    connection.updateExpiryTimer()
    return 0

  var written: int
  var buffer = newSeqUninit[byte](writeBufferSize)
  var datagram = Datagram()

  while true:
    # Stream might be blocked, waiting in case there are multiple 
    # async ops trying to write to same stream
    await connection.waitUntilUnblocked(streamId)
    datagram =
      connection.trySend(buffer, streamId, messagePtr, messageLen, addr written, isFin)
    if datagram.data.len != 0:
      connection.onSend(datagram)
      connection.updateExpiryTimer()
      return written

    # It's possible that trySend returns an empty datagram
    # because congestion or flow control, meaning that we
    # cannot send pkts yet. We have to wait to retry until 
    # we are unblocked wither by ngtcp expiry handler or by
    # having received a pkt 
    connection.flowing.clear()
    await connection.flowing.wait()

template pendingAckQueue*(
    connection: Ngtcp2Connection, stream_id: int64
): PendingAckQueue =
  if connection.pendingAckQueues.hasKey(stream_id):
    try:
      connection.pendingAckQueues[stream_id]
    except KeyError:
      raiseAssert "checked with hasKey"
  else:
    let pendingAckQueue = PendingAckQueue.new()
    connection.pendingAckQueues[stream_id] = pendingAckQueue
    pendingAckQueue

proc send*(
    connection: Ngtcp2Connection, streamId: int64, bytes: seq[byte], isFin: bool = false
) {.async: (raises: [CancelledError, QuicError]).} =
  ## Send payloads
  var messagePtr = bytes.toUnsafePtr
  var messageLen = bytes.len.uint
  connection.pendingAckQueue(streamId).push(bytes)
  var done = false
  while not done:
    let written = await connection.send(streamId, messagePtr, messageLen, isFin)
    if written >= 0:
      messagePtr = messagePtr + written
      messageLen = messageLen - written.uint
      done = messageLen == 0

proc ackSentBytes*(
    connection: Ngtcp2Connection, streamId: int64, offset: uint64, dataLen: uint64
) =
  connection.pendingAckQueue(streamId).ack(offset, dataLen)

proc tryReceive(connection: Ngtcp2Connection, datagram: sink seq[byte], ecn: ECN) =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  var packetInfo: ngtcp2_pkt_info
  packetInfo.ecn = ecn.uint8
  checkResult ngtcp2_conn_read_pkt_versioned(
    conn,
    connection.path.toPathPtr,
    NGTCP2_PKT_INFO_V1,
    addr packetInfo,
    datagram.toUnsafePtr,
    datagram.len.uint,
    now(),
  )

proc receive(
    connection: Ngtcp2Connection, datagram: sink seq[byte], ecn = ecnNonCapable
) =
  connection.tryReceive(datagram, ecn)
  connection.send()
  connection.flowing.fire()

proc receive*(connection: Ngtcp2Connection, datagram: sink Datagram) =
  connection.receive(datagram.data, datagram.ecn)

proc handleTimeout(connection: Ngtcp2Connection) =
  let conn = connection.conn.valueOr:
    return

  try:
    let ret = ngtcp2_conn_handle_expiry(conn, now())
    trace "handleExpiry", code = ret
    if ret == NGTCP2_ERR_IDLE_CLOSE:
      trace "Connection has expired!"
      connection.onTimeout()
    else:
      checkResult ret
      connection.send()
      connection.flowing.fire()
  except QuicError as e:
    error "handleTimeout unexpected error", msg = e.msg

proc close*(connection: Ngtcp2Connection): Datagram =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  if (
    ngtcp2_conn_in_closing_period(conn) == 1 or ngtcp2_conn_in_draining_period(conn) == 1
  ):
    return

  var ccerr: ngtcp2_ccerr
  ngtcp2_ccerr_default(addr ccerr)

  var packetInfo: ngtcp2_pkt_info
  var buffer = newSeqUninit[byte](writeBufferSize)
  let length = ngtcp2_conn_write_connection_close_versioned(
    conn,
    connection.path.toPathPtr,
    NGTCP2_PKT_INFO_V1,
    addr packetInfo,
    addr buffer[0],
    buffer.len.uint,
    addr ccerr,
    now(),
  )
  checkResult length.cint
  buffer.setLen(length)
  let ecn = ECN(packetInfo.ecn)

  Datagram(data: buffer, ecn: ecn)

  # TODO: should stop all event loops

proc closingDuration*(connection: Ngtcp2Connection): Duration =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  3 * ngtcp2_conn_get_pto(conn).int64.nanoseconds

proc isDraining*(connection: Ngtcp2Connection): bool =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  ngtcp2_conn_in_draining_period(conn).bool

proc isHandshakeCompleted*(connection: Ngtcp2Connection): bool =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  ngtcp2_conn_get_handshake_completed(conn).bool

proc openUniStream*(connection: Ngtcp2Connection, userdata: pointer): int64 =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult ngtcp2_conn_open_uni_stream(conn, addr result, userdata)

proc openBidiStream*(connection: Ngtcp2Connection, userdata: pointer): int64 =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult ngtcp2_conn_open_bidi_stream(conn, addr result, userdata)

proc setStreamUserData*(
    connection: Ngtcp2Connection, streamId: int64, userdata: pointer
) =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult ngtcp2_conn_set_stream_user_data(conn, streamId, userdata)

proc extendStreamOffset*(
    connection: Ngtcp2Connection, streamId: int64, amount: uint64
) =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult conn.ngtcp2_conn_extend_max_stream_offset(streamId, amount)
  conn.ngtcp2_conn_extend_max_offset(amount)

proc shutdownStream*(connection: Ngtcp2Connection, streamId: int64) =
  let conn = connection.conn.valueOr:
    raise newException(Ngtcp2ConnectionClosed, "connection no longer exists")

  checkResult ngtcp2_conn_shutdown_stream(conn, 0, streamId, 0)

proc certificates*(connection: Ngtcp2Connection): seq[seq[byte]] =
  return getFullCertChain(connection.ssl)
