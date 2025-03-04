import std/sequtils
import pkg/unittest2
import pkg/stew/endians2
import pkg/quic/transport/packets
import pkg/quic/helpers/bits
import pkg/quic/transport/packets/varints

suite "packet writing":
  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "writes short/long form":
    datagram.write(shortPacket())
    check datagram[0].bits[0] == 0
    datagram.write(initialPacket())
    check datagram[0].bits[0] == 1

  test "writes fixed bit":
    datagram.write(shortPacket())
    check datagram[0].bits[1] == 1
    datagram.write(initialPacket())
    check datagram[0].bits[1] == 1

  test "writes packet type":
    datagram.write(initialPacket())
    check datagram[0] == 0b11000000
    datagram.write(zeroRttPacket())
    check datagram[0] == 0b11010000
    datagram.write(handshakePacket())
    check datagram[0] == 0b11100000
    datagram.write(retryPacket())
    check datagram[0] == 0b11110000

  test "writes version":
    var packet = initialPacket(version = 0xAABBCCDD'u32)
    datagram.write(packet)
    check datagram[1 .. 4] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes source and destination":
    const source = @[1'u8, 2'u8]
    const destination = @[3'u8, 4'u8, 5'u8]
    var packet = initialPacket()
    packet.source = ConnectionId(source)
    packet.destination = ConnectionId(destination)
    datagram.write(packet)
    check datagram[5] == destination.len.uint8
    check datagram[6 .. 8] == destination
    check datagram[9] == source.len.uint8
    check datagram[10 .. 11] == source

  test "writes supported version for a version negotiation packet":
    const versions = @[0xAABBCCDD'u32, 0x11223344'u32]
    datagram.write(versionNegotiationPacket(versions = versions))
    check datagram[7 .. 10] == versions[0].toBytesBE
    check datagram[11 .. 14] == versions[1].toBytesBE

  test "writes retry token":
    var packet = retryPacket()
    packet.retry.token = @[1'u8, 2'u8, 3'u8]
    datagram.write(packet)
    check datagram[7 ..< packet.len - 16] == packet.retry.token

  test "writes retry integrity tag":
    var packet = retryPacket()
    packet.retry.integrity[0 ..< 16] = repeat(0xB'u8, 16)
    datagram.write(packet)
    check datagram[packet.len - 16 ..< packet.len] == packet.retry.integrity

  test "writes handshake packet length":
    const packetnumber = 0xAABBCCDD'u32
    const payload = repeat(0xAB'u8, 1024)
    var packet = handshakePacket()
    packet.handshake.packetnumber = packetnumber.int64
    packet.handshake.payload = payload
    datagram.write(packet)
    check datagram[7 .. 8] == (sizeof(packetnumber) + payload.len).toVarInt

  test "writes handshake packet number":
    const packetnumber = 0xAABBCCDD'u32
    var packet = handshakePacket()
    packet.handshake.packetnumber = packetnumber.int64
    datagram.write(packet)
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[8 .. 11] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes handshake payload":
    const payload = repeat(0xAB'u8, 1024)
    var packet = handshakePacket()
    packet.handshake.payload = payload
    datagram.write(packet)
    check datagram[10 .. 1033] == payload

  test "writes 0-RTT packet length":
    const packetnumber = 0xAABBCCDD'u32
    const payload = repeat(0xAB'u8, 1024)
    var packet = zeroRttPacket()
    packet.rtt.packetnumber = packetnumber.int64
    packet.rtt.payload = payload
    datagram.write(packet)
    check datagram[7 .. 8] == (sizeof(packetnumber) + payload.len).toVarInt

  test "writes 0-RTT packet number":
    const packetnumber = 0xAABBCCDD'u32
    var packet = zeroRttPacket()
    packet.rtt.packetnumber = packetnumber.int64
    datagram.write(packet)
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[8 .. 11] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes 0-RTT payload":
    const payload = repeat(0xAB'u8, 1024)
    var packet = zeroRttPacket()
    packet.rtt.payload = payload
    datagram.write(packet)
    check datagram[10 .. 1033] == payload

  test "writes initial token":
    const token = repeat(0xAA'u8, 1024)
    var packet = initialPacket()
    packet.initial.token = token
    datagram.write(packet)
    check datagram[7 .. 8] == token.len.toVarInt
    check datagram[9 .. 1032] == token

  test "writes initial packet length":
    const packetnumber = 0xAABBCCDD'u32
    const payload = repeat(0xAB'u8, 1024)
    var packet = initialPacket()
    packet.initial.packetnumber = packetnumber.int64
    packet.initial.payload = payload
    datagram.write(packet)
    check datagram[8 .. 9] == (sizeof(packetnumber) + payload.len).toVarInt

  test "writes initial packet number":
    const packetnumber = 0xAABBCCDD'u32
    var packet = initialPacket()
    packet.initial.packetnumber = packetnumber.int64
    datagram.write(packet)
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[9 .. 12] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes initial payload":
    const payload = repeat(0xAB'u8, 1024)
    var packet = initialPacket()
    packet.initial.payload = payload
    datagram.write(packet)
    check datagram[11 .. 1034] == payload

  test "writes spin bit":
    var packet = shortPacket()
    packet.short.spinBit = false
    datagram.write(packet)
    check datagram[0].bits[2] == 0
    packet.short.spinBit = true
    datagram.write(packet)
    check datagram[0].bits[2] == 1

  test "writes reserved bits for short packet":
    datagram[0].bits[3] = 1
    datagram[0].bits[4] = 1
    datagram.write(shortPacket())
    check datagram[0].bits[3] == 0
    check datagram[0].bits[4] == 0

  test "writes key phase for short packet":
    var packet = shortPacket()
    packet.short.keyPhase = false
    datagram.write(packet)
    check datagram[0].bits[5] == 0
    packet.short.keyPhase = true
    datagram.write(packet)
    check datagram[0].bits[5] == 1

  test "writes destination connection id for short packet":
    const destination = @[1'u8, 2'u8, 3'u8]
    var packet = shortPacket()
    packet.destination = ConnectionId(destination)
    datagram.write(packet)
    check datagram[1 .. 3] == destination

  test "writes packet number for short packet":
    const packetnumber = 0xAABB'u16
    var packet = shortPacket()
    packet.short.packetnumber = packetnumber.int64
    datagram.write(packet)
    check int(datagram[0] and 0b11'u8) + 1 == sizeof(packetnumber)
    check datagram[1 .. 2] == @[0xAA'u8, 0xBB'u8]

  test "writes payload for short packet":
    const payload = repeat(0xAB'u8, 1024)
    var packet = shortPacket()
    packet.short.payload = payload
    datagram.write(packet)
    check datagram[2 .. 1025] == payload

  test "returns the number of bytes that were written":
    let payload = repeat(0xAA'u8, 1024)
    var packet = shortPacket()
    packet.short.payload = payload
    check datagram.write(packet) == packet.len
