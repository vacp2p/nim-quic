import std/unittest
import pkg/quic/transport/packets
import pkg/quic/transport/parsedatagram

suite "parse ngtcp2 packet info":

  var packet: Packet
  var datagram: array[4096, byte]

  setup:
    packet = initialPacket(42'u32)
    packet.source = randomConnectionId()
    packet.destination = randomConnectionId()
    datagram = typeof(datagram).default
    datagram.write(packet)

  test "extracts destination id":
    let info = parseDatagram(datagram)
    check info.destination == packet.destination

  test "extracts source id":
    let info = parseDatagram(datagram)
    check info.source == packet.source

  test "extracts version":
    let info = parseDatagram(datagram)
    check info.version == packet.initial.version
