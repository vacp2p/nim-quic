import unittest
import quic

suite "multiple packets":

  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "writes multiple packets into a datagram":
    let packet1 = Packet(form: formLong, kind: packetInitial)
    let packet2 = Packet(form: formLong, kind: packetHandshake)
    datagram.write(@[packet1, packet2])
    check datagram[0] == 0b11_00_0000 # initial
    check datagram[packet1.len] == 0b11_10_0000 # handshake

  test "writes packet number lengths correctly":
    var packet1, packet2 = Packet(form: formLong)
    packet1.initial.packetnumber = 0xAABBCC
    packet2.initial.packetnumber = 0xAABBCCDD
    datagram.write(@[packet1, packet2])
    check datagram[0] == 0b110000_10 # packet number length 3
    check datagram[packet1.len] == 0b110000_11 # packet number length 4

  test "returns the number of bytes that were written":
    let packet1 = Packet(form: formLong, kind: packetInitial)
    let packet2 = Packet(form: formLong, kind: packetHandshake)
    check datagram.write(@[packet1, packet2]) == packet1.len + packet2.len
