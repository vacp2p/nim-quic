import chronos
import chronicles
import results
import std/sets
import bearssl/rand

import ./listener
import ./connection
import ./udp/datagram
import ./errors
import ./transport/tlsbackend
import ./transport/stream
import ./helpers/rand

export Listener
export accept
export Connection
export Stream
export openStream
export localAddress
export remoteAddress
export incomingStream
export read
export write
export closeWrite
export closeRead
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
export TimeOutError
export ClosedStreamError
export certificates

type TLSConfig* = object
  certificate: seq[byte]
  key: seq[byte]
  alpn: HashSet[string]
  certificateVerifier: Opt[CertificateVerifier]

type Quic = ref object of RootObj
  rng: ref HmacDrbgContext
  tlsConfig: TLSConfig

type QuicClient* = object of Quic

type QuicServer* = object of Quic

proc init*(
    t: typedesc[TLSConfig],
    certificate: seq[byte] = @[],
    key: seq[byte] = @[],
    alpn: seq[string] = @[],
    certificateVerifier: Opt[CertificateVerifier] = Opt.none(CertificateVerifier),
): TLSConfig {.gcsafe, raises: [QuicConfigError].} =
  # In a config, certificate and keys are optional, but if using them, both must
  # be specified at the same time
  if certificate.len != 0 or key.len != 0:
    if certificate.len == 0:
      raise newException(QuicConfigError, "certificate is required in TLSConfig")

    if key.len == 0:
      raise newException(QuicConfigError, "key is required in TLSConfig")

  return TLSConfig(
    certificate: certificate,
    key: key,
    certificateVerifier: certificateVerifier,
    alpn: toHashSet(alpn),
  )

proc init*(
    t: typedesc[QuicServer], tlsConfig: TLSConfig, rng: ref HmacDrbgContext = newRng()
): QuicServer {.raises: [QuicConfigError].} =
  if tlsConfig.certificate.len == 0:
    raise newException(QuicConfigError, "tlsConfig does not contain a certificate")

  return QuicServer(tlsConfig: tlsConfig, rng: rng)

proc init*(
    t: typedesc[QuicClient], tlsConfig: TLSConfig, rng: ref HmacDrbgContext = newRng()
): QuicClient {.raises: [].} =
  return QuicClient(tlsConfig: tlsConfig, rng: rng)

proc listen*(
    self: QuicServer, address: TransportAddress
): Listener {.raises: [QuicError, TransportOsError].} =
  let tlsBackend = newServerTLSBackend(
    self.tlsConfig.certificate, self.tlsConfig.key, self.tlsConfig.alpn,
    self.tlsConfig.certificateVerifier,
  )

  return newListener(tlsBackend, address, self.rng)

proc dial*(
    self: QuicClient, address: TransportAddress
): Future[Connection] {.
    async: (raises: [CancelledError, TimeOutError, QuicError, TransportOsError])
.} =
  let tlsBackend = newClientTLSBackend(
    self.tlsConfig.certificate, self.tlsConfig.key, self.tlsConfig.alpn,
    self.tlsConfig.certificateVerifier,
  )
  var connection: Connection
  proc onReceive(
      udp: DatagramTransport, remote: TransportAddress
  ) {.async: (raises: []).} =
    try:
      connection.receive(Datagram(data: udp.getMessage()))
    except TransportError as e:
      error "Unexpect transport error", errorMsg = e.msg
    except QuicError as e:
      error "Failed to receive datagram", errorMsg = e.msg

  let udp = newDatagramTransport(onReceive)
  connection = newOutgoingConnection(tlsBackend, udp, address, self.rng)

  try:
    connection.startHandshake()
    await connection.waitForHandshake()
  # whatever error happens we need to destroy tlsBackend to free resources
  except CancelledError as e:
    tlsBackend.destroy()
    raise e
  except TimeOutError as e:
    tlsBackend.destroy()
    raise e
  except QuicError as e:
    tlsBackend.destroy()
    raise e

  return connection
