import std/unittest
import std/sequtils
import quic
import ../helpers/addresses

suite "udp":

  var ecn: ECN

  setup:
    ecn = ECN.default

  test "writes packets to datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    check client.write(ecn).len > 0

  test "reads packets from datagram":
    let client = newClientConnection(zeroAddress, zeroAddress)
    let datagram = client.write(ecn)
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)
    server.read(datagram, ecn)

  test "raises error when reading datagram fails":
    let datagram = repeat(0'u8, 4096)
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.read(datagram)
