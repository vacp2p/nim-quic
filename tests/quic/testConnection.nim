import unittest
import chronos
import quic
import ../helpers/connections
import ../helpers/addresses

suite "connection":

  test "performs handshake":
    let (client, server) = performHandshake()

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted

  test "raises error when datagram that starts server connection is invalid":
    let invalid = @[0'u8]

    expect IOError:
      discard  newServerConnection(zeroAddress, zeroAddress, invalid)
