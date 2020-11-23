import std/random
import pkg/chronos
import pkg/quic
import ./addresses

type Counter* = ref object
  count*: int

proc networkLoop*(source, destination: Connection,
                  counter = Counter()) {.async.} =
  while true:
    let datagram = await source.outgoing.get()
    destination.receive(datagram)
    inc counter.count

proc simulateNetwork*(a, b: Connection, messageCounter = Counter()) {.async.} =
  let loop1 = networkLoop(a, b, messageCounter)
  let loop2 = networkLoop(b, a, messageCounter)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc lossyNetworkLoop*(source, destination: Connection) {.async.} =
  while true:
    let datagram = await source.outgoing.get()
    if rand(1.0) < 0.2:
      destination.receive(datagram)

proc simulateLossyNetwork*(a, b: Connection) {.async.} =
  let loop1 = lossyNetworkLoop(a, b)
  let loop2 = lossyNetworkLoop(b, a)
  try:
    await allFutures(loop1, loop2)
  except CancelledError:
    await allFutures(loop1.cancelAndWait(), loop2.cancelAndWait())

proc performHandshake*: Future[tuple[client, server: Connection]] {.async.} =

  let client = newClientConnection(zeroAddress, zeroAddress)
  client.send()

  let datagram = await client.outgoing.get()

  let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
  server.receive(datagram)

  let clientLoop = networkLoop(client, server)
  let serverLoop = networkLoop(server, client)

  await allFutures(client.handshake.wait(), server.handshake.wait())

  serverLoop.cancel()
  clientLoop.cancel()

  result = (client, server)
