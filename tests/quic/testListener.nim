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
      defer: await connection.close()
      check connection != nil
      done()

    listener.udp = newDatagramTransport(onReceive, local = address)
    await exampleQuicDatagram().sendTo(address)

  asynctest "re-uses connection for known connection id", done:
    let listener = newListener()
    defer: await listener.stop()

    var connection: Connection
    proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
      if connection == nil:
        connection = await listener.getOrCreateConnection(udp, remote)
      else:
        check connection == await listener.getOrCreateConnection(udp, remote)
        await connection.close()
        done()

    listener.udp = newDatagramTransport(onReceive, local = address)
    let datagram = exampleQuicDatagram()
    await datagram.sendTo(address)
    await datagram.sendTo(address)

  asynctest "creates new connection for unknown connection id", done:
    let listener = newListener()
    defer: await listener.stop()

    var connection: Connection
    proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
      if connection == nil:
        connection = await listener.getOrCreateConnection(udp, remote)
      else:
        check connection != await listener.getOrCreateConnection(udp, remote)
        await connection.close()
        done()

    listener.udp = newDatagramTransport(onReceive, local = address)
    await exampleQuicDatagram().sendTo(address)
    await exampleQuicDatagram().sendTo(address)
