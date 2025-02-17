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

type Quic = ref object of RootObj
  tlsBackend: TLSBackend

type QuicClient* = ref object of Quic
type QuicServer* = ref object of Quic

proc init*[T: QuicClient | QuicServer](t: typedesc[T], certificate: seq[byte] = @[], key: seq[byte] = @[]): Result[T, string] =
  ok(T(
    tlsBackend: ?TLSBackend.init(T is QuicServer, certificate, key)
  ))

proc destroy*[T: QuicClient | QuicServer](t: T) =
  t.tlsBackend.destroy()

proc listen*(self: QuicServer, address: TransportAddress): Listener =
  newListener(self.tlsBackend, address)

proc accept*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.waitForIncoming()

proc dial*(self: QuicClient, address: TransportAddress): Future[Connection] {.async.} =
  var connection: Connection
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let datagram = Datagram(data: udp.getMessage())
    connection.receive(datagram)
  let udp = newDatagramTransport(onReceive)
  connection = newOutgoingConnection(self.tlsBackend, udp, address).valueOr:
    raise newException(QuicError, error)
  connection.startHandshake()
  result = connection
