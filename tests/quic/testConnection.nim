import unittest
import quic
import ngtcp2
import helpers/path

suite "connection":

  test "performs handshake":
    var datagram: array[16348, uint8]
    var datagramInfo: ngtcp2_pkt_info
    var datagramLength = 0

    let client = newClientConnection(zeroPath)
    datagramLength = client.write(datagram, datagramInfo)

    let server = newServerConnection(zeroPath, datagram)
    server.read(datagram[0..<datagramLength], datagramInfo)

    datagramLength = server.write(datagram, datagramInfo)
    client.read(datagram[0..<datagramLength], datagramInfo)

    datagramLength = client.write(datagram, datagramInfo)
    server.read(datagram[0..<datagramLength], datagramInfo)

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted
