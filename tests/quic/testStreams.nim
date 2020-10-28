import std/unittest
import quic
import ../helpers/connections
import ../helpers/addresses
import ../helpers/contains

suite "streams":

  test "opens uni-directional streams":
    let (client, _) = performHandshake()

    check client.openStream() != client.openStream()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()

  test "writes to stream":
    let stream = performHandshake().client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    var datagram: array[4096, byte]
    let length = stream.write(message, datagram)
    check datagram[0..<length].contains(message)
