import chronos
import results
import ./listener
import ./connection
import ./udp/datagram
import ./errors
import ./transport/tlsbackend

export Listener
export Connection
export Stream
export openStream
export localAddress
export remoteAddress
export incomingStream
export read
export write
export stop
export drop
export close
export waitClosed
export errors

type Quic* = ref object
  clientTLSBackend: TLSBackend

proc init*(t: typedesc[Quic], certificate: seq[byte] = @[], key: seq[byte] = @[]): Result[Quic, string] =
  let clientTLSBackend = ?TLSBackend.init(certificate, key)
  ok(Quic(
    clientTLSBackend: clientTLSBackend
  ))

proc listen*(self: Quic, address: TransportAddress): Listener =
  # TODO: create context for listening the first time
  newListener(address)

proc accept*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.waitForIncoming()

proc dial*(self: Quic, address: TransportAddress): Future[Connection] {.async.} =
  var connection: Connection
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let datagram = Datagram(data: udp.getMessage())
    connection.receive(datagram)
  let udp = newDatagramTransport(onReceive)
  connection = newOutgoingConnection(self.clientTLSBackend, udp, address).valueOr:
    raise newException(QuicError, error)
  connection.startHandshake()
  result = connection
