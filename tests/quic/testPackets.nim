import std/unittest
import pkg/quic/transport/packets
import pkg/quic/transport/version

suite "packet creation":
  test "short packets":
    check shortPacket() == Packet(form: formShort)

  test "initial packets":
    let packet = initialPacket()
    check packet.form == formLong
    check packet.kind == packetInitial
    check packet.initial.version == CurrentQuicVersion

  test "0-RTT packets":
    let packet = zeroRttPacket()
    check packet.form == formLong
    check packet.kind == packet0RTT
    check packet.rtt.version == CurrentQuicVersion

  test "handshake packets":
    let packet = handshakePacket()
    check packet.form == formLong
    check packet.kind == packetHandshake
    check packet.handshake.version == CurrentQuicVersion

  test "retry packets":
    let packet = retryPacket()
    check packet.form == formLong
    check packet.kind == packetRetry
    check packet.retry.version == CurrentQuicVersion

  test "version negotiation packets":
    let packet = versionNegotiationPacket()
    check packet.form == formLong
    check packet.kind == packetVersionNegotiation
    check packet.negotiation.supportedVersions == @[CurrentQuicVersion]

suite "multiple packets":
  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "writes multiple packets into a datagram":
    let packet1 = initialPacket()
    let packet2 = handshakePacket()
    datagram.write(@[packet1, packet2])
    check datagram[0] == 0b11_00_0000 # initial
    check datagram[packet1.len] == 0b11_10_0000 # handshake

  test "writes packet number lengths correctly":
    var packet1, packet2 = initialPacket()
    packet1.initial.packetnumber = 0xAABBCC
    packet2.initial.packetnumber = 0xAABBCCDD
    datagram.write(@[packet1, packet2])
    check datagram[0] == 0b110000_10 # packet number length 3
    check datagram[packet1.len] == 0b110000_11 # packet number length 4

  test "returns the number of bytes that were written":
    let packet1 = initialPacket()
    let packet2 = handshakePacket()
    check datagram.write(@[packet1, packet2]) == packet1.len + packet2.len

  test "reads multiple packets from a datagram":
    var packet1 = initialPacket()
    var packet2 = handshakePacket()
    let length = datagram.write(@[packet1, packet2])
    check datagram[0 ..< length].readPackets() == @[packet1, packet2]
