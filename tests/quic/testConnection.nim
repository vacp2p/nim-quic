import chronos
import chronos/unittest2/asynctests
import results
import std/sets

import quic/connection
import quic/transport/tlsbackend
import quic/helpers/rand
import ../helpers/udp

suite "connections":
  setup:
    let address = initTAddress("127.0.0.1:45346")

  asyncTest "handles error when writing to udp transport by closing connection":
    let udp = newDatagramTransport()
    let tlsBackend =
      newClientTLSBackend(@[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier))
    let connection = newOutgoingConnection(tlsBackend, udp, address, newRng())
    await udp.closeWait()
    connection.startHandshake()

    await connection.waitClosed()
