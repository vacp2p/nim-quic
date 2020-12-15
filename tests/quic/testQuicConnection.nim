import std/unittest
import pkg/chronos
import pkg/quic/transport/quicconnection
import pkg/quic/transport/quicclient
import pkg/quic/udp/datagram
import ../helpers/asynctest
import ../helpers/addresses

suite "quic connection":

  asynctest "raises ConnectionError when closed":
    let connection = newQuicClientConnection(zeroAddress, zeroAddress)
    connection.drop()

    expect ConnectionError:
      connection.send()

    expect ConnectionError:
      connection.receive(Datagram(data: @[]))

    expect ConnectionError:
      discard await connection.openStream()

  test "has empty list of ids when closed":
    let connection = newQuicClientConnection(zeroAddress, zeroAddress)
    connection.drop()

    check connection.ids.len == 0
