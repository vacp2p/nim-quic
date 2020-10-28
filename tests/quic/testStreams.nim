import std/unittest
import quic
import ../helpers/connections
import ../helpers/addresses

suite "streams":

  test "opens uni-directional streams":
    let (client, _) = performHandshake()

    check client.openStream() != client.openStream()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()
