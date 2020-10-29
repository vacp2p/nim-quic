import std/unittest
import std/sequtils
import quic
import ../helpers/addresses

suite "udp":

  test "writes packets to datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    check client.write().len > 0

  test "reads packets from datagram":
    let client = newClientConnection(zeroAddress, zeroAddress)
    let datagram = client.write()
    let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
    server.read(datagram)

  test "raises error when reading datagram fails":
    let datagram = repeat(0'u8, 4096)
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.read(datagram)
