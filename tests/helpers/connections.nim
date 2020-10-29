import quic
import addresses

proc performHandshake*: tuple[client, server: Connection] =

  var datagram: Datagram

  let client = newClientConnection(zeroAddress, zeroAddress)
  datagram = client.write()

  let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
  server.read(datagram)

  datagram = server.write()
  client.read(datagram)

  datagram = client.write()
  server.read(datagram)

  (client, server)
