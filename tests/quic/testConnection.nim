import unittest
import sequtils
import chronos
import quic
import ../helpers/connections
import ../helpers/addresses

suite "connection":

  test "performs handshake":
    let (client, server) = performHandshake()

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted

  test "opens uni-directional streams":
    let (client, _) = performHandshake()

    check client.openStream() != client.openStream()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()

  test "raises error when reading datagram fails":
    let datagram = repeat(0'u8, 4096)
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.read(datagram)

  test "raises error when datagram that starts server connection is invalid":
    let invalid = @[0'u8]

    expect IOError:
      discard  newServerConnection(zeroAddress, zeroAddress, invalid)
