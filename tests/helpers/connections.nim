import chronos
import quic
import addresses

proc networkLoop(source, destination: Connection) {.async.} =
  while true:
    let datagram = await source.outgoing.get()
    destination.receive(datagram)

proc performHandshake*: Future[tuple[client, server: Connection]] {.async.} =

  let client = newClientConnection(zeroAddress, zeroAddress)
  let clientHandshake = client.handshake()

  let datagram = await client.outgoing.get()

  let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
  server.receive(datagram)
  let serverHandshake = server.handshake()

  let clientLoop = networkLoop(client, server)
  let serverLoop = networkLoop(server, client)

  await allFutures(clientHandshake, serverHandshake)

  serverLoop.cancel()
  clientLoop.cancel()

  result = (client, server)
