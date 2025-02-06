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
export destroy

type TLSConfig* = object
  certificate*: seq[byte]
  key*: seq[byte]
  # verifyCertificate = Opt[proc] # None to skip verif
  # 

proc init*(t: typedesc[TLSConfig], certificate, key: seq[byte]): TLSConfig =
  return TLSConfig(certificate: certificate, key: key)

proc listen*(
    address: TransportAddress, tlsConfig: TLSConfig
): Listener {.raises: [QuicConfigError, QuicError, TransportOsError].} =
  if tlsConfig.certificate.len == 0:
    raise newException(QuicConfigError, "certificate is required in TLSConfig")

  if tlsConfig.key.len == 0:
    raise newException(QuicConfigError, "key is required in TLSConfig")

  let tlsBackend = TLSBackend.init(true, tlsConfig.certificate, tlsConfig.key)

  return newListener(tlsBackend, address)

proc accept*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.waitForIncoming()

proc dial*(
    address: TransportAddress, tlsConfig: TLSConfig = TLSConfig()
): Future[Connection] {.async: (raises: [QuicError, TransportOsError]).} =
  let tlsBackend = TLSBackend.init(false, tlsConfig.certificate, tlsConfig.key)
  var connection: Connection
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let datagram = Datagram(data: udp.getMessage())
    connection.receive(datagram)

  let udp = newDatagramTransport(onReceive)
  connection = newOutgoingConnection(tlsBackend, udp, address)
  connection.startHandshake()
  return connection
