import pkg/chronos
import ./listener
import ./connection
import ./ngtcp2

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

export close
