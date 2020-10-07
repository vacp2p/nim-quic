import unittest
import ngtcp2
import helpers/server
import helpers/client
import helpers/ids
import helpers/path
import helpers/udp
import helpers/handshake

suite "ngtcp2":

  test "default settings":
    var settings: ngtcp2_settings
    ngtcp2_settings_default(addr settings)
    check settings.transport_params.max_udp_payload_size > 0
    check settings.transport_params.active_connection_id_limit > 0

  test "performs handshake":
    var datagram: array[16348, uint8]
    var datagramInfo: ngtcp2_pkt_info
    var datagramLength = 0

    let client = setupClient(zeroPath, randomConnectionId(), randomConnectionId())
    datagramLength = client.write(datagram, datagramInfo)

    let server = setupServer(zeroPath, randomConnectionId(), datagram)
    server.read(datagram[0..<datagramLength], datagramInfo)

    datagramLength = server.write(datagram, datagramInfo)
    client.read(datagram[0..<datagramLength], datagramInfo)

    datagramLength = client.write(datagram, datagramInfo)
    server.read(datagram[0..<datagramLength], datagramInfo)

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted
