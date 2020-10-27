import quic
import addresses

proc performHandshake*: tuple[client, server: Connection] =

  var datagram: array[16348, uint8]
  var datagramLength: int
  var ecn: ECN

  let client = newClientConnection(zeroAddress, zeroAddress)
  datagramLength = client.write(datagram, ecn)

  let server = newServerConnection(zeroAddress, zeroAddress, datagram)
  server.read(datagram[0..<datagramLength], ecn)

  datagramLength = server.write(datagram, ecn)
  client.read(datagram[0..<datagramLength], ecn)

  datagramLength = client.write(datagram, ecn)
  server.read(datagram[0..<datagramLength], ecn)

  (client, server)
