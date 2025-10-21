import std/[random, sets]
import chronos
import quic/transport/[quicconnection, quicclientserver, tlsbackend]
import quic/helpers/[asyncloop, rand]
import ./certificate
import ./addresses

proc networkLoop*(source, destination: QuicConnection) {.async.} =
  proc transfer() {.async: (raises: [CancelledError]).} =
    let datagram = await source.outgoing.get()
    try:
      destination.receive(datagram)
    except CatchableError as e:
      # this is used in tests so it's fine to raise defect
      raise newException(Defect, e.msg)

  await asyncLoop(transfer)

proc simulateNetwork*(a, b: QuicConnection) {.async.} =
  let loop1 = networkLoop(a, b)
  let loop2 = networkLoop(b, a)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc lossyNetworkLoop*(source, destination: QuicConnection) {.async.} =
  proc transfer() {.async: (raises: [CancelledError]).} =
    let datagram = await source.outgoing.get()
    if rand(1.0) < 0.2:
      try:
        destination.receive(datagram)
      except CatchableError as e:
        # this is used in tests so it's fine to raise defect
        raise newException(Defect, e.msg)

  await asyncLoop(transfer)

proc simulateLossyNetwork*(a, b: QuicConnection) {.async.} =
  let loop1 = lossyNetworkLoop(a, b)
  let loop2 = lossyNetworkLoop(b, a)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc setupConnection*(): Future[tuple[client, server: QuicConnection]] {.async.} =
  let rng = newRng()
  let clientTLSBackend =
    newClientTLSBackend(@[], @[], toHashSet(@["test"]), Opt.none(CertificateVerifier))
  let client = newQuicClientConnection(clientTLSBackend, zeroAddress, zeroAddress, rng)

  client.send() # Start Handshake
  let datagram = await client.outgoing.get()
  let serverTLSBackend = newServerTLSBackend(
    testCertificate(),
    testPrivateKey(),
    toHashSet(@["test"]),
    Opt.none(CertificateVerifier),
  )
  let server =
    newQuicServerConnection(serverTLSBackend, zeroAddress, zeroAddress, datagram, rng)

  result = (client, server)

proc performHandshake*(): Future[tuple[client, server: QuicConnection]] {.async.} =
  let (client, server) = await setupConnection()
  let clientLoop = networkLoop(client, server)
  let serverLoop = networkLoop(server, client)
  await allFutures(client.handshake.wait(), server.handshake.wait())
  await serverLoop.cancelAndWait()
  await clientLoop.cancelAndWait()
  result = (client, server)
