import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic
import pkg/quic/listener
import ../helpers/udp

suite "listener":

  setup:
    var listener = newListener(initTAddress("127.0.0.1:0"))
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
