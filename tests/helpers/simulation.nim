import std/[random, sets]
import pkg/chronos
import pkg/quic/transport/[quicconnection, quicclientserver, tlsbackend]
import pkg/quic/helpers/asyncloop
import ./certificate
import ./addresses

proc networkLoop*(source, destination: QuicConnection) {.async.} =
  proc transfer() {.async.} =
    let datagram = await source.outgoing.get()
    destination.receive(datagram)

  await asyncLoop(transfer)

proc simulateNetwork*(a, b: QuicConnection) {.async.} =
  let loop1 = networkLoop(a, b)
  let loop2 = networkLoop(b, a)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc lossyNetworkLoop*(source, destination: QuicConnection) {.async.} =
  proc transfer() {.async.} =
    let datagram = await source.outgoing.get()
    if rand(1.0) < 0.2:
      destination.receive(datagram)

  await asyncLoop(transfer)

proc simulateLossyNetwork*(a, b: QuicConnection) {.async.} =
  let loop1 = lossyNetworkLoop(a, b)
  let loop2 = lossyNetworkLoop(b, a)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc setupConnection*(): Future[tuple[client, server: QuicConnection]] {.async.} =
  let clientTLSBackend =
    newClientTLSBackend(@[], @[], toHashSet(@["test"]), Opt.none(CertificateVerifier))
  let client = newQuicClientConnection(clientTLSBackend, zeroAddress, zeroAddress)

  client.send() # Start Handshake
  let datagram = await client.outgoing.get()
  let serverTLSBackend = newServerTLSBackend(
    testCertificate(),
    testPrivateKey(),
    toHashSet(@["test"]),
    Opt.none(CertificateVerifier),
  )
  let server =
    newQuicServerConnection(serverTLSBackend, zeroAddress, zeroAddress, datagram)

  result = (client, server)

proc performHandshake*(): Future[tuple[client, server: QuicConnection]] {.async.} =
  let (client, server) = await setupConnection()
  let clientLoop = networkLoop(client, server)
  let serverLoop = networkLoop(server, client)
  await allFutures(client.handshake.wait(), server.handshake.wait())
  await serverLoop.cancelAndWait()
  await clientLoop.cancelAndWait()
  result = (client, server)
