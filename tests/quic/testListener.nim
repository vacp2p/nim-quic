import std/unittest
import pkg/chronos
import pkg/quic
import pkg/quic/listener
import pkg/quic/packets
import pkg/quic/version
import pkg/quic/connectionid
import ../helpers/asynctest
import ../helpers/udp

suite "listener":

  let address = initTAddress("127.0.0.1:45346")

  proc exampleDatagram: seq[byte] =
    var packet = initialPacket(CurrentQuicVersion)
    packet.destination = randomConnectionId()
    result = newSeq[byte](4096)
    result.write(packet)

  asynctest "creates a new connection", done:
    let listener = newListener()
    defer: await listener.stop()

    proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
      let connection = await listener.getOrCreateConnection(udp, remote)
      defer: await connection.close()
      check connection != nil
      done()

    listener.udp = newDatagramTransport(onReceive, local=address)
    await exampleDatagram().sendTo(address)
