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

proc drop*(connection: Connection) {.async: (raises: [CancelledError, QuicError]).} =
  trace "Dropping connection"
  await connection.quic.drop()

proc close*(connection: Connection) {.async: (raises: [CancelledError, QuicError]).} =
  await connection.quic.close()
  if connection is OutgoingConnection:
    let outConn = OutgoingConnection(connection)
    if outConn.tlsBackend.isSome:
      outConn.tlsBackend.get().destroy()
      outConn.tlsBackend = Opt.none(TLSBackend)

proc waitClosed*(connection: Connection) {.async: (raises: [CancelledError]).} =
  await connection.closed.wait()
  if connection is OutgoingConnection:
    let outConn = OutgoingConnection(connection)
    if outConn.tlsBackend.isSome:
      outConn.tlsBackend.get().destroy()
      outConn.tlsBackend = Opt.none(TLSBackend)

proc startSending(connection: Connection, remote: TransportAddress) =
  trace "Starting sending loop"
  proc onStop(e: ref CatchableError) {.async: (raises: []).} =
    if not connection.loop.finished:
      connection.loop.fail(e)
    try:
      await connection.drop()
    except CatchableError as e:
      trace "Failed to drop connection", msg = e.msg

  proc send() {.async: (raises: [CancelledError]).} =
    try:
      let datagram = await connection.quic.outgoing.get()
      await connection.udp.sendTo(remote, datagram.data)
    except CancelledError as e:
      await onStop(e)
    except TransportError as e:
      trace "Failed to send datagram", errorMsg = e.msg
      await onStop(e)

  connection.loop = asyncLoop(send)

proc stopSending(connection: Connection) {.async: (raises: [CancelledError]).} =
  trace "Stopping sending loop"
  await connection.loop.cancelAndWait()

method closeUdp(connection: Connection) {.async: (raises: []), base.} =
  discard

method closeUdp(connection: OutgoingConnection) {.async: (raises: []).} =
  await connection.udp.closeWait()

proc disconnect(connection: Connection) {.async: (raises: [CancelledError]).} =
  trace "Disconnecting connection"
  await connection.stopSending()
  await connection.closeUdp()
  if connection.onClose.isSome():
    (connection.onClose.unsafeGet())()
  connection.closed.fire()

proc newIncomingConnection*(
    tlsBackend: TLSBackend,
    udp: DatagramTransport,
    msg: seq[byte],
    remote: TransportAddress,
    rng: ref HmacDrbgContext,
): Connection =
  let datagram = Datagram(data: msg)
  let quic =
    newQuicServerConnection(tlsBackend, udp.localAddress, remote, datagram, rng)
  let closed = newAsyncEvent()
  let connection = IncomingConnection(udp: udp, quic: quic, closed: closed)
  proc onDisconnect() {.async: (raises: [CancelledError]).} =
    trace "Calling onDisconnect for newIncomingConnection"
    await connection.disconnect()

  connection.remote = remote
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)
  connection

proc ensureClosed(
    connection: Connection
) {.async: (raises: [CancelledError, QuicError]).} =
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
  proc onDisconnect() {.async: (raises: [CancelledError]).} =
    trace "Calling onDisconnect for newOutgoingConnection"
    await connection.disconnect()

  connection.remote = remote
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)

  asyncSpawn connection.ensureClosed()

  connection

proc startHandshake*(connection: Connection) {.gcsafe.} =
  connection.quic.send()

proc waitForHandshake*(
    connection: Connection
) {.async: (raises: [CancelledError, QuicError, TimeOutError]).} =
  let key = connection.quic.error.register()
  defer:
    connection.quic.error.unregister(key)

  let errFut = connection.quic.error.waitEvents(key)
  let timeoutFut = connection.quic.timeout.wait()
  let handshakeFut = connection.quic.handshake.wait()
  let raceFut =
    try:
      await race(handshakeFut, timeoutFut, errFut)
    except CancelledError as e:
      let connCloseFut = connection.close()
      handshakeFut.cancelSoon()
      errFut.cancelSoon()
      timeoutFut.cancelSoon()
      await connCloseFut
      raise e

  if raceFut == timeoutFut:
    let connCloseFut = connection.close()
    errFut.cancelSoon()
    handshakeFut.cancelSoon()
    await connCloseFut
    raise newException(TimeOutError, "connection handshake timed out")
  elif raceFut == errFut:
    let connCloseFut = connection.close()
    timeoutFut.cancelSoon()
    handshakeFut.cancelSoon()
    await connCloseFut

    let err =
      try:
        await errFut
      except AsyncEventQueueFullError as e:
        raise newException(
          QuicError, "connection handshake error: waiting on error: " & e.msg
        )

    raise newException(QuicError, "connection handshake error: " & err[0])
  else:
    errFut.cancelSoon()
    timeoutFut.cancelSoon()

proc receive*(connection: Connection, datagram: sink Datagram) =
  connection.quic.receive(datagram)

proc remoteAddress*(connection: Connection): TransportAddress {.raises: [].} =
  connection.remote

proc localAddress*(
    connection: Connection
): TransportAddress {.raises: [TransportOsError].} =
  connection.udp.localAddress()

proc handleNewStream(
    connection: Connection,
    streamFut: Future[Stream].Raising([CancelledError, QuicError]),
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  let closedFut = connection.closed.wait()
  let raceFut = await race(streamFut, closedFut)
  if raceFut == closedFut:
    raise newException(QuicError, "connection closed")

  return await streamFut

proc incomingStream*(
    connection: Connection
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  return await connection.handleNewStream(connection.quic.incomingStream())

proc openStream*(
    connection: Connection, unidirectional = false
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  return await connection.handleNewStream(connection.quic.openStream(unidirectional))

proc certificates*(connection: Connection): seq[seq[byte]] =
  connection.quic.certificates()
