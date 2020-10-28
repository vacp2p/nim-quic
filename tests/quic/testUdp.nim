import std/unittest
import quic
import ../helpers/addresses

suite "udp":

  var datagram: array[4096, byte]
  var ecn: ECN

  setup:
    datagram = array[4096, byte].default
    ecn = ECN.default

  test "writes packets to datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    check client.write(datagram, ecn) > 0

  test "reads packets from datagram":
    let client = newClientConnection(zeroAddress, zeroAddress)
    let length = client.write(datagram, ecn)
    let server = newServerConnection(zeroAddress, zeroAddress, datagram[0..<length])
    server.read(datagram[0..<length], ecn)

  test "raises error when reading datagram fails":
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.read(datagram)
