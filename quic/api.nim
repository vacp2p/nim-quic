import pkg/chronos
import ./listener
import ./connection
import ./udp/datagram

export Listener
export Connection
export Stream
export openStream
export incomingStream
export read
export write
export stop
export drop
export close
export waitClosed

proc listen*(address: TransportAddress): Listener =
  newListener(address)

proc accept*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.waitForIncoming()

proc dial*(address: TransportAddress): Future[Connection] {.async.} =
  var connection: Connection
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let datagram = Datagram(data: udp.getMessage())
    connection.receive(datagram)
  let udp = newDatagramTransport(onReceive)
  connection = newOutgoingConnection(udp, address)
  connection.startHandshake()
  result = connection
