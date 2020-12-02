import pkg/chronos
import ./asyncloop
import ./ngtcp2/connection
import ./ngtcp2/server
import ./ngtcp2/client
import ./ngtcp2/handshake
import ./ngtcp2/streams

export Ngtcp2Connection
export newClientConnection
export newServerConnection
export receive, send
export isHandshakeCompleted
export handshake
export Stream
export openStream
export close
export read, write
export incomingStream
export destroy

type
  Listener* = ref object
    udp: DatagramTransport
    incoming: AsyncQueue[Connection]
    connection: Connection
  Connection* = ref object
    udp: DatagramTransport
    quic: Ngtcp2Connection
    loop: Future[void]
    closed: bool

proc startSending(connection: Connection, remote: TransportAddress) =
  proc send {.async.} =
    let datagram = await connection.quic.outgoing.get()
    await connection.udp.sendTo(remote, datagram.data)
  connection.loop = asyncLoop(send)

proc stopSending(connection: Connection) {.async.} =
  await connection.loop.cancelAndWait()

proc newIncomingConnection(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newServerConnection(udp.localAddress, remote, udp.getMessage())
  result = Connection(udp: udp, quic: quic)
  result.startSending(remote)

proc newOutgoingConnection(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newClientConnection(udp.localAddress, remote)
  result = Connection(udp: udp, quic: quic)
  result.startSending(remote)

proc newListener: Listener =
  Listener(incoming: newAsyncQueue[Connection]())

proc getOrCreateConnection(listener: Listener,
                           udp: DatagramTransport,
                           remote: TransportAddress):
                           Future[Connection] {.async.} =
  if listener.connection.isNil:
    listener.connection = newIncomingConnection(udp, remote)
    await listener.incoming.put(listener.connection)
  result = listener.connection

proc listen*(address: TransportAddress): Listener =
  var listener = newListener()
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let connection = await listener.getOrCreateConnection(udp, remote)
    connection.quic.receive(udp.getMessage())
  listener.udp = newDatagramTransport(onReceive, local = address)
  listener

proc accept*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.incoming.get()

proc stop*(listener: Listener) {.async.} =
  await listener.udp.closeWait()

proc close*(connection: Connection) {.async.} =
  if not connection.closed:
    connection.closed = true
    await connection.stopSending()
    await connection.udp.closeWait()
    connection.quic.destroy()

proc dial*(address: TransportAddress): Future[Connection] {.async.} =
  var connection: Connection
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let datagram = udp.getMessage()
    connection.quic.receive(datagram)
  let udp = newDatagramTransport(onReceive)
  connection = newOutgoingConnection(udp, address)
  connection.quic.send()
  result = connection

proc openStream*(connection: Connection): Future[Stream] {.async.} =
  await connection.quic.handshake.wait()
  result = connection.quic.openStream()
