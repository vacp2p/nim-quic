import std/random
import pkg/chronos
import pkg/quic/transport/ngtcp2
import pkg/quic/helpers/asyncloop
import ./addresses

proc networkLoop*(source, destination: Ngtcp2Connection) {.async.} =
  proc transfer {.async.} =
    let datagram = await source.outgoing.get()
    destination.receive(datagram)
  await asyncLoop(transfer)

proc simulateNetwork*(a, b: Ngtcp2Connection) {.async.} =
  let loop1 = networkLoop(a, b)
  let loop2 = networkLoop(b, a)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc lossyNetworkLoop*(source, destination: Ngtcp2Connection) {.async.} =
  proc transfer {.async.} =
    let datagram = await source.outgoing.get()
    if rand(1.0) < 0.2:
      destination.receive(datagram)
  await asyncLoop(transfer)

proc simulateLossyNetwork*(a, b: Ngtcp2Connection) {.async.} =
  let loop1 = lossyNetworkLoop(a, b)
  let loop2 = lossyNetworkLoop(b, a)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc setupConnection*:
                Future[tuple[client, server: Ngtcp2Connection]] {.async.} =

  let client = newClientConnection(zeroAddress, zeroAddress)
  client.send()
  let datagram = await client.outgoing.get()
  let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
  server.receive(datagram)
  result = (client, server)


proc performHandshake*:
                Future[tuple[client, server: Ngtcp2Connection]] {.async.} =
  let (client, server) = await setupConnection()
  let clientLoop = networkLoop(client, server)
  let serverLoop = networkLoop(server, client)
  await allFutures(client.handshake.wait(), server.handshake.wait())
  serverLoop.cancel()
  clientLoop.cancel()
  result = (client, server)
