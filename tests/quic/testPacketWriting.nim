import unittest
import sequtils
import stew/endians2
import quic
import quic/bits
import quic/varints

suite "packet writing":

  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "writes short/long form":
    datagram.write(Packet(form: formShort))
    check datagram[0].bits[0] == 0
    datagram.write(Packet(form: formLong))
    check datagram[0].bits[0] == 1

  test "writes fixed bit":
    datagram.write(Packet(form: formShort))
    check datagram[0].bits[1] == 1
    datagram.write(Packet(form: formLong))
    check datagram[0].bits[1] == 1

  test "writes packet type":
    datagram.write(Packet(form: formLong, kind: packetInitial))
    check datagram[0] == 0b11000000
    datagram.write(Packet(form: formLong, kind: packet0RTT))
    check datagram[0] == 0b11010000
    datagram.write(Packet(form: formLong, kind: packetHandshake))
    check datagram[0] == 0b11100000
    datagram.write(Packet(form: formLong, kind: packetRetry))
    check datagram[0] == 0b11110000

  test "writes version":
    var packet = Packet(form: formLong, kind: packetInitial)
    packet.initial.version = 0xAABBCCDD'u32
    datagram.write(packet)
    check datagram[1..4] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes source and destination":
    const source = @[1'u8, 2'u8]
    const destination = @[3'u8, 4'u8, 5'u8]
    var packet = Packet(form: formLong)
    packet.source = ConnectionId(source)
    packet.destination = ConnectionId(destination)
    datagram.write(packet)
    check datagram[5] == destination.len.uint8
    check datagram[6..8] == destination
    check datagram[9] == source.len.uint8
    check datagram[10..11] == source

  test "writes supported version for a version negotiation packet":
    const supportedVersion = 0xAABBCCDD'u32
    var packet = Packet(form: formLong, kind: packetVersionNegotiation)
    packet.negotiation.supportedVersion = supportedVersion
    datagram.write(packet)
    check datagram[7..10] == supportedVersion.toBytesBE

  test "writes retry token":
    var packet = Packet(form: formLong, kind: packetRetry)
    packet.retry.token = @[1'u8, 2'u8, 3'u8]
    datagram.write(packet)
    check datagram[7..<packet.len-16] == packet.retry.token

  test "writes retry integrity tag":
    var packet = Packet(form: formLong, kind: packetRetry)
    packet.retry.integrity[0..<16] = repeat(0xB'u8, 16)
    datagram.write(packet)
    check datagram[packet.len-16..<packet.len] == packet.retry.integrity

  test "writes handshake packet number":
    const packetnumber = 0xAABBCCDD'u32
    var packet = Packet(form: formLong, kind: packetHandshake)
    packet.handshake.packetnumber = packetnumber
    datagram.write(packet)
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[8..11] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes handshake payload":
    const payload = repeat(0xAB'u8, 1024)
    var packet = Packet(form: formLong, kind: packetHandshake)
    packet.handshake.payload = payload
    datagram.write(packet)
    check datagram[7..8] == payload.len.toVarInt
    check datagram[10..1033] == payload

  test "writes 0-RTT packet number":
    const packetnumber = 0xAABBCCDD'u32
    var packet = Packet(form: formLong, kind: packet0RTT)
    packet.rtt.packetnumber = packetnumber
    datagram.write(packet)
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[8..11] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes 0-RTT payload":
    const payload = repeat(0xAB'u8, 1024)
    var packet = Packet(form: formLong, kind: packet0RTT)
    packet.rtt.payload = payload
    datagram.write(packet)
    check datagram[7..8] == payload.len.toVarInt
    check datagram[10..1033] == payload

  test "writes initial token":
    const token = repeat(0xAA'u8, 1024)
    var packet = Packet(form: formLong, kind: packetInitial)
    packet.initial.token = token
    datagram.write(packet)
    check datagram[7..8] == token.len.toVarInt
    check datagram[9..1032] == token

  test "writes initial packet number":
    const packetnumber = 0xAABBCCDD'u32
    var packet = Packet(form: formLong, kind: packetInitial)
    packet.initial.packetnumber = packetnumber
    datagram.write(packet)
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[9..12] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes initial payload":
    const payload = repeat(0xAB'u8, 1024)
    var packet = Packet(form: formLong, kind: packetInitial)
    packet.initial.payload = payload
    datagram.write(packet)
    check datagram[8..9] == payload.len.toVarInt
    check datagram[11..1034] == payload

  test "writes spin bit":
    datagram.write(Packet(form: formShort, short: PacketShort(spinBit: false)))
    check datagram[0].bits[2] == 0
    datagram.write(Packet(form: formShort, short: PacketShort(spinBit: true)))
    check datagram[0].bits[2] == 1

  test "writes reserved bits for short packet":
    datagram[0].bits[3] = 1
    datagram[0].bits[4] = 1
    datagram.write(Packet(form: formShort))
    check datagram[0].bits[3] == 0
    check datagram[0].bits[4] == 0

  test "writes key phase for short packet":
    datagram.write(Packet(form: formShort, short: PacketShort(keyPhase: false)))
    check datagram[0].bits[5] == 0
    datagram.write(Packet(form: formShort, short: PacketShort(keyPhase: true)))
    check datagram[0].bits[5] == 1

  test "writes destination connection id for short packet":
    const destination = @[1'u8, 2'u8, 3'u8]
    let packet = Packet(form: formShort, destination: ConnectionId(destination))
    datagram.write(packet)
    check datagram[1..3] == destination

  test "writes packet number for short packet":
    const packetnumber = 0xAABB'u16
    datagram.write(Packet(form: formShort, short: PacketShort(packetnumber: packetnumber)))
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[1..2] == @[0xAA'u8, 0xBB'u8]

  test "writes payload for short packet":
    const payload = repeat(0xAB'u8, 1024)
    var packet = Packet(form: formShort, short: PacketShort(payload: payload))
    datagram.write(packet)
    check datagram[2..1025] == payload

  test "returns the number of bytes that were written":
    let payload = repeat(0xAA'u8, 1024)
    let packet = Packet(form: formShort, short: PacketShort(payload: payload))
    check datagram.write(packet) == packet.len
