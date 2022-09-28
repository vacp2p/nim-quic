import ./basics
import ./transport/connectionid
import ./transport/stream
import ./transport/quicconnection
import ./transport/quicclientserver
import ./helpers/asyncloop

export Stream, close, read, write

type
  Connection* = ref object of RootObj
    udp: DatagramTransport
    quic: QuicConnection
    loop: Future[void]
    onClose: Opt[proc() {.gcsafe, upraises: [].}]
    closed: AsyncEvent
  IncomingConnection = ref object of Connection
  OutgoingConnection = ref object of Connection

proc ids*(connection: Connection): seq[ConnectionId] =
  connection.quic.ids

proc `onNewId=`*(connection: Connection, callback: IdCallback) =
  connection.quic.onNewId = callback

proc `onRemoveId=`*(connection: Connection, callback: IdCallback) =
  connection.quic.onRemoveId = callback

proc `onClose=`*(connection: Connection, callback: proc() {.gcsafe, upraises: [].}) =
  connection.onClose = Opt.some(callback)

proc drop*(connection: Connection) {.async.} =
  await connection.quic.drop()

proc close*(connection: Connection) {.async.} =
  await connection.quic.close()

proc waitClosed*(connection: Connection) {.async.} =
  await connection.closed.wait()

proc startSending(connection: Connection, remote: TransportAddress) =
  proc send {.async.} =
    try:
      let datagram = await connection.quic.outgoing.get()
      await connection.udp.sendTo(remote, datagram.data)
    except TransportError:
      await connection.drop()
  connection.loop = asyncLoop(send)

proc stopSending(connection: Connection) {.async.} =
  await connection.loop.cancelAndWait()

method closeUdp(connection: Connection) {.async, base, upraises: [].} =
  discard

method closeUdp(connection: OutgoingConnection) {.async.} =
  await connection.udp.closeWait()

proc disconnect(connection: Connection) {.async.} =
  await connection.stopSending()
  await connection.closeUdp()
  if connection.onClose.isSome():
    (connection.onClose.unsafeGet())()
  connection.closed.fire()

proc newIncomingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let datagram = Datagram(data: udp.getMessage())
  let quic = newQuicServerConnection(udp.localAddress, remote, datagram)
  let closed = newAsyncEvent()
  let connection = IncomingConnection(udp: udp, quic: quic, closed: closed)
  proc onDisconnect {.async.} =
    await connection.disconnect()
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)
  connection

proc newOutgoingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newQuicClientConnection(udp.localAddress, remote)
  let closed = newAsyncEvent()
  let connection = OutgoingConnection(udp: udp, quic: quic, closed: closed)
  proc onDisconnect {.async.} =
    await connection.disconnect()
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)
  connection

proc startHandshake*(connection: Connection) =
  connection.quic.send()

proc receive*(connection: Connection, datagram: Datagram) =
  connection.quic.receive(datagram)

proc openStream*(connection: Connection,
                 unidirectional = false): Future[Stream] {.async.} =
  await connection.quic.handshake.wait()
  result = await connection.quic.openStream(unidirectional = unidirectional)

proc incomingStream*(connection: Connection): Future[Stream] {.async.} =
  result = await connection.quic.incomingStream()
