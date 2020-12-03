import std/unittest
import pkg/chronos
import pkg/quic
import pkg/quic/listener
import pkg/quic/connectionid
import ../helpers/asynctest
import ../helpers/udp

suite "listener":

  let address = initTAddress("127.0.0.1:45346")

  asynctest "creates connections", done:
    let listener = newListener()
    defer: await listener.stop()

    proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
      let connection = await listener.getOrCreateConnection(udp, remote)
      check connection != nil
      await connection.close()
      done()

    listener.udp = newDatagramTransport(onReceive, local = address)
    await exampleQuicDatagram().sendTo(address)

  asynctest "re-uses connection for known connection id", done:
    let listener = newListener()
    defer: await listener.stop()

    var first, second: Connection
    proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
      if first == nil:
        first = await listener.getOrCreateConnection(udp, remote)
      else:
        second = await listener.getOrCreateConnection(udp, remote)
        check first == second
        await first.close()
        await second.close()
        done()

    listener.udp = newDatagramTransport(onReceive, local = address)
    let datagram = exampleQuicDatagram()
    await datagram.sendTo(address)
    await datagram.sendTo(address)

  asynctest "creates new connection for unknown connection id", done:
    let listener = newListener()
    defer: await listener.stop()

    var first, second: Connection
    proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
      if first == nil:
        first = await listener.getOrCreateConnection(udp, remote)
      else:
        second = await listener.getOrCreateConnection(udp, remote)
        check first != second
        await first.close()
        await second.close()
        done()

    listener.udp = newDatagramTransport(onReceive, local = address)
    await exampleQuicDatagram().sendTo(address)
    await exampleQuicDatagram().sendTo(address)
