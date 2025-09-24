import std/unittest

import ngtcp2
import quic/helpers/rand
import quic/transport/[packets, parsedatagram, version]

suite "parse ngtcp2 packet info":
  var packet: Packet
  var datagram: array[4096, byte]

  setup:
    let rng = newRng()
    packet = initialPacket(CurrentQuicVersion)
    packet.source = randomConnectionId(rng)
    packet.destination = randomConnectionId(rng)
    datagram = typeof(datagram).default
    datagram.write(packet)

  test "extracts destination id":
    let info = parseDatagramInfo(datagram)
    check info.destination == packet.destination

    let destination = parseDatagramDestination(datagram)
    check info.destination == destination

  test "extracts source id":
    let info = parseDatagramInfo(datagram)
    check info.source == packet.source

  test "extracts version":
    let info = parseDatagramInfo(datagram)
    check info.version == packet.initial.version
