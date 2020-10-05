import unittest
import std/monotimes
import ngtcp2
import helpers/server
import helpers/client
import helpers/ids
import helpers/path

suite "ngtcp2":

  test "default settings":
    var settings: ngtcp2_settings
    ngtcp2_settings_default(addr settings)
    check settings.transport_params.max_udp_payload_size > 0
    check settings.transport_params.active_connection_id_limit > 0

  test "open connection":
    var clientId, randomId, serverId = randomConnectionId()

    let client = setupClient(addr zeroPath, addr clientId, addr randomId)
    defer: ngtcp2_conn_del(client)

    var packet: array[16348, uint8]
    var packetInfo: ngtcp2_pkt_info

    # handshake client -> server
    echo "--- CLIENT 1>>> SERVER"
    check packet.len == client.ngtcp2_conn_write_stream(addr zeroPath, addr packetInfo, addr packet[0], packet.len.uint, nil, NGTCP2_WRITE_STREAM_FLAG_MORE.uint32, -1, nil, 0, getMonoTime().ticks.uint)

    # check that package is acceptable initial packet
    var packetHeader: ngtcp2_pkt_hd
    check 0 == ngtcp2_accept(addr packetHeader, addr packet[0], packet.len.uint)

    # extract version number, source and destination id
    var packetVersion: uint32
    var packetDestinationId: ptr uint8
    var packetDestinationIdLen: uint
    var packetSourceId: ptr uint8
    var packetSourceIdLen: uint
    assert 0 == ngtcp2_pkt_decode_version_cid(addr packetVersion, addr packetDestinationId, addr packetDestinationIdLen, addr packetSourceId, addr packetSourceIdLen, addr packet[0], packet.len.uint, 18)
    var serverDestinationId = connectionId(packetSourceId, packetSourceIdLen)
    check serverDestinationId == clientId

    # setup server connection using received id
    let server = setupServer(addr zeroPath, addr serverId, addr serverDestinationId)
    defer: ngtcp2_conn_del(server)

    echo "--- CLIENT >>>1 SERVER"
    check 0 == server.ngtcp2_conn_read_pkt(addr zeroPath, addr packetInfo, addr packet[0], packet.len.uint, getMonoTime().ticks.uint)

    echo "--- CLIENT <<<2 SERVER"
    var offset = 0
    block:
      var length = 1
      offset = 0
      while length > 0:
        length = server.ngtcp2_conn_write_stream(addr zeroPath, addr packetInfo, addr packet[offset], (packet.len - offset).uint, nil, NGTCP2_WRITE_STREAM_FLAG_MORE.uint32, -1, nil, 0, getMonoTime().ticks.uint)
        offset = offset + length

    echo "--- CLIENT 2<<< SERVER"
    check 0 == client.ngtcp2_conn_read_pkt(addr zeroPath, addr packetInfo, addr packet[0], offset.uint, getMonoTime().ticks.uint)

    echo "--- CLIENT 3>>> SERVER"
    check packet.len == client.ngtcp2_conn_write_pkt(addr zeroPath, addr packetInfo, addr packet[0], packet.len.uint, getMonoTime().ticks.uint)

    check client.ngtcp2_conn_get_handshake_completed().bool

    echo "--- CLIENT >>>3 SERVER"
    check 0 == server.ngtcp2_conn_read_pkt(addr zeroPath, addr packetInfo, addr packet[0], packet.len.uint, getMonoTime().ticks.uint)

    check server.ngtcp2_conn_get_handshake_completed().bool
