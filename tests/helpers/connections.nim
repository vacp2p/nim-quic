import chronos
import quic
import addresses

proc performHandshake*: Future[tuple[client, server: Connection]] {.async.} =

  var datagram: Datagram

  let client = newClientConnection(zeroAddress, zeroAddress)
  await client.write()
  datagram = await client.outgoing.get()

  let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
  server.read(datagram)

  await server.write()
  datagram = await server.outgoing.get()
  client.read(datagram)

  await client.write()
  datagram = await client.outgoing.get()
  server.read(datagram)

  result = (client, server)
