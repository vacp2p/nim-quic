import std/unittest
import pkg/chronos
import pkg/quic
import pkg/quic/listener
import ../helpers/asynctest
import ../helpers/udp

suite "listener":

  let address = initTAddress("127.0.0.1:45346")

  asynctest "creates connections":
    let listener = newListener(address)
    defer: await listener.stop()

    await exampleQuicDatagram().sendTo(address)
    let connection = await listener.waitForIncoming()

    check connection != nil

    await connection.drop()

  asynctest "re-uses connection for known connection id":
    let listener = newListener(address)
    defer: await listener.stop()

    let datagram = exampleQuicDatagram()
    await datagram.sendTo(address)
    await datagram.sendTo(address)

    let first = await listener.waitForIncoming.wait(100.milliseconds)
    expect AsyncTimeoutError:
      discard await listener.waitForIncoming.wait(100.milliseconds)
    await first.drop()

  asynctest "creates new connection for unknown connection id":
    let listener = newListener(address)
    defer: await listener.stop()

    await exampleQuicDatagram().sendTo(address)
    await exampleQuicDatagram().sendTo(address)

    let first = await listener.waitForIncoming.wait(100.milliseconds)
    let second = await listener.waitForIncoming.wait(100.milliseconds)

    await first.drop()
    await second.drop()

  asynctest "forgets connection ids when connection closes":
    let listener = newListener(address)
    defer: await listener.stop()

    let datagram = exampleQuicDatagram()
    await datagram.sendTo(address)

    let first = await listener.waitForIncoming.wait(100.milliseconds)
    await first.drop()

    await datagram.sendTo(address)

    let second = await listener.waitForIncoming.wait(100.milliseconds)
    await second.drop()
