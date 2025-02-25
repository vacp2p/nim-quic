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
export CertificateVerifier
export certificateVerifierCB
export CustomCertificateVerifier
export InsecureCertificateVerifier
export init

type TLSConfig* = object
  certificate*: seq[byte]
  key*: seq[byte]
  certificateVerifier*: Opt[CertificateVerifier]

proc init*(
    t: typedesc[TLSConfig],
    certificate: seq[byte] = @[],
    key: seq[byte] = @[],
    certificateVerifier: Opt[CertificateVerifier] = Opt.none(CertificateVerifier),
): TLSConfig {.gcsafe.} =
  return TLSConfig(
    certificate: certificate, key: key, certificateVerifier: certificateVerifier
  )

proc newBackend(self: TLSConfig, isServer: bool): TLSBackend {.gcsafe.}  =
  TLSBackend.init(isServer, self.certificate, self.key, self.certificateVerifier)

proc listen*(
    address: TransportAddress, tlsConfig: TLSConfig
): Listener {.raises: [QuicConfigError, QuicError, TransportOsError].} =
  if tlsConfig.certificate.len == 0:
    raise newException(QuicConfigError, "certificate is required in TLSConfig")

  if tlsConfig.key.len == 0:
    raise newException(QuicConfigError, "key is required in TLSConfig")

  let tlsBackend = tlsConfig.newBackend(true)

  return newListener(tlsBackend, address)

proc accept*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.waitForIncoming()

proc dial*(
    address: TransportAddress, tlsConfig: TLSConfig = TLSConfig()
): Future[Connection] {.async: (raises: [QuicError, TransportOsError]).} =
  let tlsBackend = tlsConfig.newBackend(false)
  var connection: Connection
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let datagram = Datagram(data: udp.getMessage())
    connection.receive(datagram)

  let udp = newDatagramTransport(onReceive)
  connection = newOutgoingConnection(tlsBackend, udp, address)
  connection.startHandshake()
  return connection
