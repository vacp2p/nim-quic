import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic/connection
import ../helpers/udp

suite "connections":

  setup:
    let address = initTAddress("127.0.0.1:45346")

  asyncTest "handles error when writing to udp transport by closing connection":
    let udp = newDatagramTransport()
    let connection = newOutgoingConnection(udp, address)

    await udp.closeWait()
    connection.startHandshake()

    await connection.waitClosed()
