import pkg/chronos
import ./stream
import ./asyncloop
import ./ngtcp2
import ./connectionid

export Stream, close, read, write

type
  Connection* = ref object of RootObj
    udp: DatagramTransport
    quic: Ngtcp2Connection
    loop: Future[void]
    closed: bool
    onClose: proc()
  IncomingConnection = ref object of Connection
  OutgoingConnection = ref object of Connection

proc ids*(connection: Connection): seq[ConnectionId] =
  connection.quic.ids

proc `onNewId=`*(connection: Connection, callback: proc(id: ConnectionId)) =
  connection.quic.onNewId = callback

proc `onRemoveId=`*(connection: Connection, callback: proc(id: ConnectionId)) =
  connection.quic.onRemoveId = callback

proc `onClose=`*(connection: Connection, callback: proc()) =
  connection.onClose = callback

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

proc incomingStream*(connection: Connection): Future[Stream] {.async.} =
  result = await connection.quic.incomingStream()

method closeUdp(connection: Connection) {.async, base.} =
  discard

method closeUdp(connection: OutgoingConnection) {.async.} =
  await connection.udp.closeWait()

proc drop*(connection: Connection) {.async.} =
  if not connection.closed:
    connection.closed = true
    await connection.stopSending()
    await connection.closeUdp()
    if connection.onClose != nil:
      connection.onClose()
    connection.quic.destroy()
