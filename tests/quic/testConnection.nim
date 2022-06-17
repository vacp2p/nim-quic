import pkg/asynctest/unittest2
import pkg/chronos
import pkg/quic/connection
import ../helpers/udp

suite "connections":

  let address = initTAddress("127.0.0.1:45346")

  test "handles error when writing to udp transport by closing connection":
    let udp = newDatagramTransport()
    let connection = newOutgoingConnection(udp, address)

    await udp.closeWait()
    connection.startHandshake()

    await connection.waitClosed()
