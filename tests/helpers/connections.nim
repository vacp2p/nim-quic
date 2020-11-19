import std/random
import chronos
import quic
import addresses

type Counter* = ref object
  count*: int

proc networkLoop*(source, destination: Connection,
                  counter = Counter()) {.async.} =
  while true:
    let datagram = await source.outgoing.get()
    destination.receive(datagram)
    inc counter.count

proc simulateNetwork*(a, b: Connection, messageCounter = Counter()) {.async.} =
  await allFutures(
    networkLoop(a, b, messageCounter),
    networkLoop(b, a, messageCounter)
  )

proc lossyNetworkLoop*(source, destination: Connection) {.async.} =
  while true:
    let datagram = await source.outgoing.get()
    if rand(1.0) < 0.2:
      destination.receive(datagram)

proc simulateLossyNetwork*(a, b: Connection) {.async.} =
  await allFutures(
    lossyNetworkLoop(a, b),
    lossyNetworkLoop(b, a)
  )

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
