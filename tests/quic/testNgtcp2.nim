import unittest
import ngtcp2
import helpers/server
import helpers/client

suite "ngtcp2":

  test "default settings":
    var settings: ngtcp2_settings
    ngtcp2_settings_default(addr settings)
    check settings.transport_params.max_udp_payload_size > 0
    check settings.transport_params.active_connection_id_limit > 0

test "open connection":
  var serverLocalAddress, serverRemoteAddress: SocketAddress
  serverLocalAddress.ipv4.sin_family = AF_INET
  serverRemoteAddress.ipv4.sin_family = AF_INET
  var serverPath = ngtcp2_path(
    local: ngtcp2_addr(`addr`: addr serverLocalAddress.address, addrlen: sizeof(SocketAddress).uint),
    remote: ngtcp2_addr(`addr`: addr serverRemoteAddress.address, addrlen: sizeof(SocketAddress).uint)
  )

  var clientLocalAddress, clientRemoteAddress: SocketAddress
  clientLocalAddress.ipv4.sin_family = AF_INET
  clientRemoteAddress.ipv4.sin_family = AF_INET
  var clientPath = ngtcp2_path(
    local: ngtcp2_addr(`addr`: addr clientLocalAddress.address, addrlen: sizeof(SocketAddress).uint),
    remote: ngtcp2_addr(`addr`: addr clientRemoteAddress.address, addrlen: sizeof(SocketAddress).uint)
  )

  let server = setupServer(addr serverPath)
  let client = setupClient(addr clientPath)
  defer: ngtcp2_conn_del(server)
  defer: ngtcp2_conn_del(client)
