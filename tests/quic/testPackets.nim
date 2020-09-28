import unittest
import sequtils
import quic
import quic/bits
import quic/varints
import stew/endians2

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
    var packet = Packet(form: formLong)
    packet.version = 0xAABBCCDD'u32
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

suite "packet reading":

  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "reads long/short form":
    datagram[0] = 0b01000000
    check readPacket(datagram).form == formShort
    datagram[0] = 0b11000000
    check readPacket(datagram).form == formLong

  test "checks fixed bit":
    datagram[0] = 0b00000000
    expect Exception:
      discard readPacket(datagram)

  test "reads packet type":
    const version = 1'u32
    datagram[1..4] = version.toBytesBE
    datagram[0] = 0b11000000
    check readPacket(datagram).kind == packetInitial
    datagram[0] = 0b11010000
    check readPacket(datagram).kind == packet0RTT
    datagram[0] = 0b11100000
    check readPacket(datagram).kind == packetHandshake
    datagram[0] = 0b11110000
    check readPacket(datagram).kind == packetRetry

  test "reads version negotiation packet":
    const version = 0'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    check readPacket(datagram).kind == packetVersionNegotiation

  test "reads version":
    const version = 0xAABBCCDD'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    check readPacket(datagram).version == version

  test "reads source and destination connection id":
    const source = @[1'u8, 2'u8, 3'u8]
    const destination = @[4'u8, 5'u8, 6'u8]
    datagram[0] = 0b11000000
    datagram[5] = destination.len.uint8
    datagram[6..8] = destination
    datagram[9] = source.len.uint8
    datagram[10..12] = source
    let packet = readPacket(datagram)
    check packet.source == ConnectionId(source)
    check packet.destination == ConnectionId(destination)

  test "reads supported version in version negotiation packet":
    const supportedVersion = 0xAABBCCDD'u32
    const version = 0'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    datagram[7..10] = supportedVersion.toBytesBE
    check readPacket(datagram).negotiation.supportedVersion == supportedVersion

  test "reads token and integrity tag from retry packet":
    const token = @[1'u8, 2'u8, 3'u8]
    const integrity = repeat(0xA'u8, 16)
    const version = 1'u32
    datagram[0] = 0b11110000
    datagram[1..4] = version.toBytesBE
    datagram[7..9] = token
    datagram[10..25] = integrity
    let packet = readPacket(datagram[0..25])
    check packet.retry.token == token
    check packet.retry.integrity == integrity

  test "reads packet number from handshake packet":
    const packetnumber = 0xABCD'u16
    const version = 1'u32
    datagram[0] = 0b111000_01 # size of packetnumber is 2
    datagram[1..4] = version.toBytesBE
    datagram[8..9] = packetnumber.toBytesBE
    let packet = readPacket(datagram)
    check packet.handshake.packetnumber == packetnumber

  test "reads payload from handshake packet":
    const payload = repeat(0xAB'u8, 1024)
    const version = 1'u32
    datagram[0] = 0b11100000
    datagram[1..4] = version.toBytesBE
    datagram[7..8] = payload.len.toVarInt
    datagram[10..1033] = payload
    let packet = readPacket(datagram)
    check packet.handshake.payload == payload

suite "packet length":

  const destination = ConnectionId(@[3'u8, 4'u8, 5'u8])
  const source = ConnectionId(@[1'u8, 2'u8])
  const token = @[0xA'u8, 0xB'u8, 0xC'u8]

  test "knows the length of a version negotiation packet":
    var packet = Packet(form: formLong, kind: packetVersionNegotiation)
    packet.destination = destination
    packet.source = source
    packet.negotiation.supportedVersion = 42
    check packet.len == 11 + destination.len + source.len

  test "knows the length of a retry packet":
    var packet = Packet(form: formLong, kind: packetRetry)
    packet.destination = destination
    packet.source = source
    packet.retry.token = token
    packet.retry.integrity[0..15] = repeat(0xA'u8, 16)
    check packet.len == 7 + destination.len + source.len + token.len + 16

  test "knows the length of a handshake packet":
    var packet = Packet(form: formLong, kind: packetHandshake)
    packet.destination = destination
    packet.source = source
    packet.handshake.packetnumber = 0x00BBCCDD'u32
    packet.handshake.payload = repeat(0xEE'u8, 1024)
    check packet.len == 7 +
      destination.len +
      source.len +
      1024.toVarInt.len + # packet length
      3 + # packet number
      1024 # payload
