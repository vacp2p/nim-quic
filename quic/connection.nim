import pkg/chronos
import ./asyncloop
import ./ngtcp2

type
  Connection* = ref object
    udp*: DatagramTransport
    quic*: Ngtcp2Connection
    loop: Future[void]
    closed*: bool
    kind*: ConnectionKind
  ConnectionKind* = enum
    incoming
    outgoing

proc startSending(connection: Connection, remote: TransportAddress) =
  proc send {.async.} =
    let datagram = await connection.quic.outgoing.get()
    await connection.udp.sendTo(remote, datagram.data)
  connection.loop = asyncLoop(send)

proc stopSending*(connection: Connection) {.async.} =
  await connection.loop.cancelAndWait()

proc newIncomingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newServerConnection(udp.localAddress, remote, udp.getMessage())
  result = Connection(udp: udp, quic: quic, kind: incoming)
  result.startSending(remote)

proc newOutgoingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newClientConnection(udp.localAddress, remote)
  result = Connection(udp: udp, quic: quic, kind: outgoing)
  result.startSending(remote)
