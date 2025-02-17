import chronos
import chronos/unittest2/asynctests
import results

import quic/connection
import quic/transport/tlsbackend
import ../helpers/udp

suite "connections":

  setup:
    let address = initTAddress("127.0.0.1:45346")

  asyncTest "handles error when writing to udp transport by closing connection":
    let udp = newDatagramTransport()
    let tlsBackend = TLSBackend.init(false, @[], @[]).valueOr:
      doAssert false, "couldnt initialize TLS backend: " & $error
      return

    let connection = newOutgoingConnection(tlsBackend, udp, address).valueOr:
      doAssert false, "couldnt obtain outgoing connection: " & $error()
      return
    
    await udp.closeWait()
    connection.startHandshake()

    await connection.waitClosed()
