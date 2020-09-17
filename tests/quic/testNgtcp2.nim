import unittest
import std/monotimes
import ngtcp2
import helpers/server
import helpers/client
import helpers/ids

suite "ngtcp2":

  test "default settings":
    var settings: ngtcp2_settings
    ngtcp2_settings_default(addr settings)
    check settings.transport_params.max_udp_payload_size > 0
    check settings.transport_params.active_connection_id_limit > 0

  test "open connection":
    var serverLocalAddress, serverRemoteAddress: SocketAddress
    serverLocalAddress.ipv4.sin_family = AF_INET
    serverLocalAddress.ipv4.sin_addr.s_addr = 1
    serverLocalAddress.ipv4.sin_port = Port(1000)
    serverRemoteAddress.ipv4.sin_family = AF_INET
    serverRemoteAddress.ipv4.sin_addr.s_addr = 2
    serverRemoteAddress.ipv4.sin_port = Port(2000)
    var serverPath = ngtcp2_path(
      local: ngtcp2_addr(`addr`: addr serverLocalAddress.address, addrlen: sizeof(SocketAddress).uint),
      remote: ngtcp2_addr(`addr`: addr serverRemoteAddress.address, addrlen: sizeof(SocketAddress).uint)
    )

    var clientLocalAddress, clientRemoteAddress: SocketAddress
    clientLocalAddress.ipv4.sin_family = AF_INET
    clientLocalAddress.ipv4.sin_addr.s_addr = 2
    clientLocalAddress.ipv4.sin_port = Port(2000)
    clientRemoteAddress.ipv4.sin_family = AF_INET
    clientRemoteAddress.ipv4.sin_addr.s_addr = 1
    clientRemoteAddress.ipv4.sin_port = Port(1000)
    var clientPath = ngtcp2_path(
      local: ngtcp2_addr(`addr`: addr clientLocalAddress.address, addrlen: sizeof(SocketAddress).uint),
      remote: ngtcp2_addr(`addr`: addr clientRemoteAddress.address, addrlen: sizeof(SocketAddress).uint)
    )

    var clientId = randomConnectionId()
    var randomId = randomConnectionId()
    var serverId = randomConnectionId()

    let client = setupClient(addr clientPath, addr clientId, addr randomId)
    defer: ngtcp2_conn_del(client)

    var packet: array[4096, uint8]
    var packetInfo: ngtcp2_pkt_info

    # handshake client -> server
    check packet.len == client.ngtcp2_conn_write_pkt(addr clientPath, addr packetInfo, addr packet[0], packet.len.uint, getMonoTime().ticks.uint)

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
    let server = setupServer(addr serverPath, addr serverId, addr serverDestinationId)
    defer: ngtcp2_conn_del(server)

    check 0 == server.ngtcp2_conn_read_pkt(addr serverPath, addr packetInfo, addr packet[0], packet.len.uint, getMonoTime().ticks.uint)
