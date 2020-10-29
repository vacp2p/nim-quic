import quic
import addresses

proc performHandshake*: tuple[client, server: Connection] =

  var datagram: seq[byte]
  var ecn: ECN

  let client = newClientConnection(zeroAddress, zeroAddress)
  datagram = client.write(ecn)

  let server = newServerConnection(zeroAddress, zeroAddress, datagram)
  server.read(datagram, ecn)

  datagram = server.write(ecn)
  client.read(datagram, ecn)

  datagram = client.write(ecn)
  server.read(datagram, ecn)

  (client, server)
