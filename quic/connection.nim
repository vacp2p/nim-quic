import pkg/chronos
import ./asyncloop
import ./ngtcp2
import ./connectionid

type
  Connection* = ref object of RootObj
    udp: DatagramTransport
    quic: Ngtcp2Connection
    loop: Future[void]
    closed: bool
  IncomingConnection = ref object of Connection
  OutgoingConnection = ref object of Connection

proc ids*(connection: Connection): seq[ConnectionId] =
  connection.quic.ids

proc `onNewId=`*(connection: Connection, callback: proc (id: ConnectionId)) =
  connection.quic.onNewId = callback

proc startSending(connection: Connection, remote: TransportAddress) =
  proc send {.async.} =
    let datagram = await connection.quic.outgoing.get()
    await connection.udp.sendTo(remote, datagram.data)
  connection.loop = asyncLoop(send)

proc stopSending(connection: Connection) {.async.} =
  await connection.loop.cancelAndWait()

proc newIncomingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newServerConnection(udp.localAddress, remote, udp.getMessage())
  result = IncomingConnection(udp: udp, quic: quic)
  result.startSending(remote)

proc newOutgoingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newClientConnection(udp.localAddress, remote)
  result = OutgoingConnection(udp: udp, quic: quic)
  result.startSending(remote)

proc startHandshake*(connection: Connection) =
  connection.quic.send()

proc receive*(connection: Connection, datagram: openArray[byte]) =
  connection.quic.receive(datagram)

proc openStream*(connection: Connection): Future[Stream] {.async.} =
  await connection.quic.handshake.wait()
  result = connection.quic.openStream()

method closeUdp(connection: Connection) {.async, base.} =
  discard

method closeUdp(connection: OutgoingConnection) {.async.} =
  await connection.udp.closeWait()

proc closeQuic(connection: Connection) {.async.} =
  connection.quic.destroy()

proc close*(connection: Connection) {.async.} =
  if not connection.closed:
    connection.closed = true
    await connection.stopSending()
    await connection.closeUdp()
    await connection.closeQuic()
