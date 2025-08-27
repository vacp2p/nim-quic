import chronos
import chronos/unittest2/asynctests
import quic
import quic/helpers/rand
import quic/listener
import quic/transport/tlsbackend
import std/sets
import ../helpers/udp
import ../helpers/certificate

suite "listener":
  setup:
    let tlsBackend = newServerTLSBackend(
      testCertificate(),
      testPrivateKey(),
      initHashSet[string](),
      Opt.none(CertificateVerifier),
    )
    var listener = newListener(tlsBackend, initTAddress("127.0.0.1:0"), newRng())
    let address = listener.localAddress

    check address.port != Port(0)

  teardown:
    waitFor listener.stop()

  asyncTest "creates connections":
    await exampleQuicDatagram().sendTo(address)
    let connection = await listener.waitForIncoming().wait(100.milliseconds)

    check connection != nil

    await connection.drop()

  asyncTest "re-uses connection for known connection id":
    let datagram = exampleQuicDatagram()
    await datagram.sendTo(address)
    await datagram.sendTo(address)

    let first = await listener.waitForIncoming.wait(100.milliseconds)
    expect AsyncTimeoutError:
      discard await listener.waitForIncoming.wait(100.milliseconds)
    await first.drop()

  asyncTest "creates new connection for unknown connection id":
    await exampleQuicDatagram().sendTo(address)
    await exampleQuicDatagram().sendTo(address)

    let first = await listener.waitForIncoming.wait(100.milliseconds)
    let second = await listener.waitForIncoming.wait(100.milliseconds)

    await first.drop()
    await second.drop()

  asyncTest "forgets connection ids when connection closes":
    let datagram = exampleQuicDatagram()
    await datagram.sendTo(address)

    let connection = await listener.waitForIncoming.wait(100.milliseconds)
    await connection.drop()

    check listener.connectionIds.len == 0
