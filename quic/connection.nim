import pkg/chronos
import pkg/questionable
import ./transport/connectionid
import ./transport/stream
import ./transport/ngtcp2
import ./transport/quicconnection
import ./transport/quicclientserver
import ./udp/datagram
import ./helpers/asyncloop

export Stream, close, read, write

type
  Connection* = ref object of RootObj
    udp: DatagramTransport
    quic: QuicConnection
    loop: Future[void]
    onClose: ?proc() {.gcsafe.}
    closed: AsyncEvent
  IncomingConnection = ref object of Connection
  OutgoingConnection = ref object of Connection

proc ids*(connection: Connection): seq[ConnectionId] =
  connection.quic.ids

proc `onNewId=`*(connection: Connection, callback: proc(id: ConnectionId)) =
  connection.quic.onNewId = callback

proc `onRemoveId=`*(connection: Connection, callback: proc(id: ConnectionId)) =
  connection.quic.onRemoveId = callback

proc `onClose=`*(connection: Connection, callback: proc() {.gcsafe.}) =
  connection.onClose = some callback

proc startSending(connection: Connection, remote: TransportAddress) =
  proc send {.async.} =
    let datagram = await connection.quic.outgoing.get()
    await connection.udp.sendTo(remote, datagram.data)
  connection.loop = asyncLoop(send)

proc stopSending(connection: Connection) {.async.} =
  await connection.loop.cancelAndWait()

method closeUdp(connection: Connection) {.async, base.} =
  discard

method closeUdp(connection: OutgoingConnection) {.async.} =
  await connection.udp.closeWait()

proc disconnect(connection: Connection) {.async.} =
  await connection.stopSending()
  await connection.closeUdp()
  if onClose =? connection.onClose:
    onClose()
  connection.closed.fire()

proc newIncomingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let datagram = Datagram(data: udp.getMessage())
  let quic = newQuicServerConnection(udp.localAddress, remote, datagram)
  let closed = newAsyncEvent()
  let connection = IncomingConnection(udp: udp, quic: quic, closed: closed)
  quic.disconnect = some proc {.async.} =
    await connection.disconnect()
  connection.startSending(remote)
  connection

proc newOutgoingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newQuicClientConnection(udp.localAddress, remote)
  let closed = newAsyncEvent()
  let connection = OutgoingConnection(udp: udp, quic: quic, closed: closed)
  quic.disconnect = some proc {.async.} =
    await connection.disconnect()
  connection.startSending(remote)
  connection

proc startHandshake*(connection: Connection) =
  connection.quic.send()

proc receive*(connection: Connection, datagram: Datagram) =
  connection.quic.receive(datagram)

proc openStream*(connection: Connection): Future[Stream] {.async.} =
  await connection.quic.handshake.wait()
  result = await connection.quic.openStream()

proc incomingStream*(connection: Connection): Future[Stream] {.async.} =
  result = await connection.quic.incomingStream()

proc drop*(connection: Connection) {.async.} =
  await connection.quic.drop()

proc close*(connection: Connection) {.async.} =
  await connection.quic.close()

proc waitClosed*(connection: Connection) {.async.} =
  await connection.closed.wait()
