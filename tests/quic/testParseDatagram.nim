import std/unittest

import ngtcp2
import bearssl/rand
import quic/helpers/rand
import quic/transport/[packets, parsedatagram, version]

suite "parse ngtcp2 packet info":
  var packet: Packet
  var datagram: array[4096, byte]
  var rng: ref HmacDrbgContext

  setup:
    packet = initialPacket(CurrentQuicVersion)
    rng = newRng()
    packet.source = randomConnectionId(rng)
    packet.destination = randomConnectionId(rng)
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
