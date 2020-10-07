import unittest
import quic
import helpers/path

suite "connection":

  test "performs handshake":
    var datagram: array[16348, uint8]
    var datagramLength = 0
    var ecn: ECN

    let client = newClientConnection(zeroPath)
    datagramLength = client.write(datagram, ecn)

    let server = newServerConnection(zeroPath, datagram)
    server.read(datagram[0..<datagramLength], ecn)

    datagramLength = server.write(datagram, ecn)
    client.read(datagram[0..<datagramLength], ecn)

    datagramLength = client.write(datagram, ecn)
    server.read(datagram[0..<datagramLength], ecn)

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted
