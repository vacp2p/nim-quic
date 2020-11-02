import quic
import addresses

proc performHandshake*: tuple[client, server: Connection] =

  var datagram: Datagram

  let client = newClientConnection(zeroAddress, zeroAddress)
  client.write()
  datagram = client.outgoing.pop()

  let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
  server.read(datagram)

  server.write()
  datagram = server.outgoing.pop()
  client.read(datagram)

  client.write()
  datagram = client.outgoing.pop()
  server.read(datagram)

  (client, server)
