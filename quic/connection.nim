import chronicles
import bearssl/rand

import ./basics
import ./transport/connectionid
import ./transport/stream
import ./transport/quicconnection
import ./transport/quicclientserver
import ./transport/tlsbackend
import ./helpers/asyncloop

export Stream, close, read, write

logScope:
  topics = "quic connection"

type
  Connection* = ref object of RootObj
    udp: DatagramTransport
    remote: TransportAddress
    quic: QuicConnection
    loop: Future[void]
    onClose: Opt[proc() {.gcsafe, raises: [].}]
    closed: AsyncEvent

  TimeOutError* = object of QuicError

  IncomingConnection = ref object of Connection

  OutgoingConnection = ref object of Connection
    tlsBackend: Opt[TLSBackend]

proc ids*(connection: Connection): seq[ConnectionId] =
  connection.quic.ids

proc `onNewId=`*(connection: Connection, callback: IdCallback) =
  connection.quic.onNewId = callback

proc `onRemoveId=`*(connection: Connection, callback: IdCallback) =
  connection.quic.onRemoveId = callback

proc `onClose=`*(connection: Connection, callback: proc() {.gcsafe, raises: [].}) =
  connection.onClose = Opt.some(callback)

proc drop*(connection: Connection) {.async.} =
  trace "Dropping connection"
  await connection.quic.drop()
  trace "Dropped connection"

proc close*(connection: Connection) {.async.} =
  await connection.quic.close()
  if connection is OutgoingConnection:
    let outConn = OutgoingConnection(connection)
    if outConn.tlsBackend.isSome:
      outConn.tlsBackend.get().destroy()
      outConn.tlsBackend = Opt.none(TLSBackend)

proc waitClosed*(connection: Connection) {.async.} =
  await connection.closed.wait()
  if connection is OutgoingConnection:
    let outConn = OutgoingConnection(connection)
    if outConn.tlsBackend.isSome:
      outConn.tlsBackend.get().destroy()
      outConn.tlsBackend = Opt.none(TLSBackend)

proc startSending(connection: Connection, remote: TransportAddress) =
  trace "Starting sending loop"
  proc send() {.async.} =
    try:
      trace "Getting datagram"
      let datagram = await connection.quic.outgoing.get()
      trace "Sending datagram"
      await connection.udp.sendTo(remote, datagram.data)
      trace "Sent datagram"
    except TransportError as e:
      trace "Failed to send datagram", errorMsg = e.msg
      trace "Failing connection loop future with error"
      if not connection.loop.finished:
        connection.loop.fail(e)
          # This might need to be revisited, see https://github.com/status-im/nim-quic/pull/41 for more details
      await connection.drop()

  connection.loop = asyncLoop(send)

proc stopSending(connection: Connection) {.async.} =
  trace "Stopping sending loop"
  await connection.loop.cancelAndWait()
  trace "Stopped sending loop"

method closeUdp(connection: Connection) {.async: (raises: []), base.} =
  discard

method closeUdp(connection: OutgoingConnection) {.async: (raises: []).} =
  await connection.udp.closeWait()

proc disconnect(connection: Connection) {.async.} =
  trace "Disconnecting connection"
  trace "Stop sending in the connection"
  await connection.stopSending()
  trace "Stopped sending in the connection"
  trace "Closing udp"
  await connection.closeUdp()
  trace "Closed udp"
  if connection.onClose.isSome():
    trace "Calling onClose"
    (connection.onClose.unsafeGet())()
    trace "Called onClose"
  trace "Firing closed event"
  connection.closed.fire()
  trace "Fired closed event"

proc newIncomingConnection*(
    tlsBackend: TLSBackend,
    udp: DatagramTransport,
    remote: TransportAddress,
    rng: ref HmacDrbgContext,
): Connection =
  let datagram = Datagram(data: udp.getMessage())
  let quic =
    newQuicServerConnection(tlsBackend, udp.localAddress, remote, datagram, rng)
  let closed = newAsyncEvent()
  let connection = IncomingConnection(udp: udp, quic: quic, closed: closed)
  proc onDisconnect() {.async.} =
    trace "Calling onDisconnect for newIncomingConnection"
    await connection.disconnect()
    trace "Called onDisconnect for newIncomingConnection"

  connection.remote = remote
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)
  connection

proc ensureClosed(connection: Connection) {.async.} =
  ## This will automatically close the connection if there's an idle timeout reported
  ## by ngtcp2
  discard await race(connection.quic.timeout.wait(), connection.closed.wait())
  await connection.close()

proc newOutgoingConnection*(
    tlsBackend: TLSBackend,
    udp: DatagramTransport,
    remote: TransportAddress,
    rng: ref HmacDrbgContext,
): Connection =
  let quic = newQuicClientConnection(tlsBackend, udp.localAddress, remote, rng)
  let closed = newAsyncEvent()
  let connection = OutgoingConnection(
    udp: udp, quic: quic, closed: closed, tlsBackend: Opt.some(tlsBackend)
  )
  proc onDisconnect() {.async.} =
    trace "Calling onDisconnect for newOutgoingConnection"
    await connection.disconnect()
    trace "Called onDisconnect for newOutgoingConnection"

  connection.remote = remote
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)

  asyncSpawn connection.ensureClosed()

  connection

proc startHandshake*(connection: Connection) {.gcsafe.} =
  connection.quic.send()

proc waitForHandshake*(
    connection: Connection
) {.async: (raises: [CancelledError, TimeOutError, CatchableError]).} =
  let key = connection.quic.error.register()
  defer:
    connection.quic.error.unregister(key)

  let errFut = connection.quic.error.waitEvents(key)
  let timeoutFut = connection.quic.timeout.wait()
  let handshakeFut = connection.quic.handshake.wait()
  let raceFut = await race(handshakeFut, timeoutFut, errFut)
  if raceFut == timeoutFut:
    let connCloseFut = connection.close()
    errFut.cancelSoon()
    handshakeFut.cancelSoon()
    await connCloseFut
    raise newException(TimeOutError, "handshake timed out")
  elif raceFut == errFut:
    let connCloseFut = connection.close()
    timeoutFut.cancelSoon()
    handshakeFut.cancelSoon()
    await connCloseFut
    let err = await errFut
    raise newException(QuicError, "connection error: " & err[0])
  else:
    errFut.cancelSoon()
    timeoutFut.cancelSoon()

proc receive*(connection: Connection, datagram: Datagram) =
  connection.quic.receive(datagram)

proc remoteAddress*(
    connection: Connection
): TransportAddress {.raises: [Defect, TransportOsError].} =
  connection.remote

proc localAddress*(
    connection: Connection
): TransportAddress {.raises: [Defect, TransportOsError].} =
  connection.udp.localAddress()

proc openStream*(
    connection: Connection, unidirectional = false
): Future[Stream] {.async.} =
  await connection.quic.openStream(unidirectional = unidirectional)

proc incomingStream*(connection: Connection): Future[Stream] {.async.} =
  await connection.quic.incomingStream()

proc certificates*(connection: Connection): seq[seq[byte]] =
  connection.quic.certificates()
