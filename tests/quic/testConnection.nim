import std/unittest
import chronos
import quic
import ../helpers/asynctest
import ../helpers/connections
import ../helpers/addresses

suite "connection":

  asynctest "performs handshake":
    let (client, server) = await performHandshake()

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted

  test "raises error when datagram that starts server connection is invalid":
    let invalid = @[0'u8]

    expect IOError:
      discard  newServerConnection(zeroAddress, zeroAddress, invalid)
