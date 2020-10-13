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

  test "opens uni-directional streams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    datagramLength = client.write(datagram, ecn)

    let server = newServerConnection(zeroAddress, zeroAddress, datagram)
    server.read(datagram[0..<datagramLength], ecn)

    datagramLength = server.write(datagram, ecn)
    client.read(datagram[0..<datagramLength], ecn)

    datagramLength = client.write(datagram, ecn)
    server.read(datagram[0..<datagramLength], ecn)

    check client.openStream() != client.openStream()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()

  test "raises error when reading datagram fails":
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.read(datagram, ecn)

  test "raises error when datagram that starts server connection is invalid":
    let invalid = datagram[0..<1]

    expect IOError:
      discard  newServerConnection(zeroAddress, zeroAddress, invalid)
