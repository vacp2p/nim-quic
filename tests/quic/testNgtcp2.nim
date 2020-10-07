import unittest
import ngtcp2
import helpers/server
import helpers/client
import helpers/ids
import helpers/path
import helpers/connection
import helpers/udp

suite "ngtcp2":

  test "default settings":
    var settings: ngtcp2_settings
    ngtcp2_settings_default(addr settings)
    check settings.transport_params.max_udp_payload_size > 0
    check settings.transport_params.active_connection_id_limit > 0

  test "open connection":
    var clientId, randomId, serverId = randomConnectionId()

    let client = setupClient(zeroPath, clientId, randomId)

    var datagram: array[16348, uint8]
    var datagramInfo: ngtcp2_pkt_info
    var datagramLength = 0

    # handshake client -> server
    echo "--- CLIENT 1>>> SERVER"
    datagramLength = client.write(datagram, datagramInfo)

    # setup server connection using received datagram
    let server = setupServer(zeroPath, serverId, datagram)

    echo "--- CLIENT >>>1 SERVER"
    server.read(datagram[0..<datagramLength], datagramInfo)

    echo "--- CLIENT <<<2 SERVER"
    datagramLength = server.write(datagram, datagramInfo)

    echo "--- CLIENT 2<<< SERVER"
    client.read(datagram[0..<datagramLength], datagramInfo)

    echo "--- CLIENT 3>>> SERVER"
    datagramLength = client.write(datagram, datagramInfo)

    check client.conn.ngtcp2_conn_get_handshake_completed().bool

    echo "--- CLIENT >>>3 SERVER"
    server.read(datagram[0..<datagramLength], datagramInfo)

    check server.conn.ngtcp2_conn_get_handshake_completed().bool
