import std/unittest
import pkg/chronos
import pkg/quic
import ../helpers/asynctest
import ../helpers/simulation
import ../helpers/addresses

suite "connection":

  asynctest "performs handshake":
    let (client, server) = await performHandshake()
    defer: client.destroy
    defer: server.destroy

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted

  test "raises error when datagram that starts server connection is invalid":
    let invalid = @[0'u8]

    expect IOError:
      discard newServerConnection(zeroAddress, zeroAddress, invalid)
