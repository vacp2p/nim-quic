import unittest
import chronos
import quic

suite "connection":

  const zeroAddress = initTAddress("0.0.0.0:0")

  var datagram: array[16348, uint8]
  var datagramLength: int
  var ecn: ECN

  setup:
    datagram = (typeof datagram).default
    datagramLength = 0
    ecn = ECN.default

  test "performs handshake":
    let client = newClientConnection(zeroAddress, zeroAddress)
    datagramLength = client.write(datagram, ecn)

    let server = newServerConnection(zeroAddress, zeroAddress, datagram)
    server.read(datagram[0..<datagramLength], ecn)

    datagramLength = server.write(datagram, ecn)
    client.read(datagram[0..<datagramLength], ecn)

    datagramLength = client.write(datagram, ecn)
    server.read(datagram[0..<datagramLength], ecn)

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted

  test "raises when reading datagram fails":
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.read(datagram, ecn)
