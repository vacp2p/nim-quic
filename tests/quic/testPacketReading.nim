import unittest
import sequtils
import stew/endians2
import quic
import quic/varints

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
    check readPacket(datagram).initial.version == version

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

  test "reads packet number from 0-RTT packet":
    const packetnumber = 0xABCD'u16
    const version = 1'u32
    datagram[0] = 0b110100_01 # size of packetnumber is 2
    datagram[1..4] = version.toBytesBE
    datagram[8..9] = packetnumber.toBytesBE
    let packet = readPacket(datagram)
    check packet.rtt.packetnumber == packetnumber

  test "reads payload from 0-RTT packet":
    const payload = repeat(0xAB'u8, 1024)
    const version = 1'u32
    datagram[0] = 0b11010000
    datagram[1..4] = version.toBytesBE
    datagram[7..8] = payload.len.toVarInt
    datagram[10..1033] = payload
    let packet = readPacket(datagram)
    check packet.rtt.payload == payload

  test "reads token from initial packet":
    const token = repeat(0xAA'u8, 1024)
    const version = 1'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    datagram[7..8] = token.len.toVarInt
    datagram[9..1032] = token
    let packet = readPacket(datagram)
    check packet.initial.token == token

  test "reads packet number from initial packet":
    const packetnumber = 0xABCD'u16
    const version = 1'u32
    datagram[0] = 0b110000_01 # size of packetnumber is 2
    datagram[1..4] = version.toBytesBE
    datagram[9..10] = packetnumber.toBytesBE
    let packet = readPacket(datagram)
    check packet.initial.packetnumber == packetnumber

  test "reads payload from initial packet":
    const payload = repeat(0xAB'u8, 1024)
    const version = 1'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    datagram[8..9] = payload.len.toVarInt
    datagram[11..1034] = payload
    let packet = readPacket(datagram)
    check packet.initial.payload == payload

  test "reads spin bit from short packet":
    datagram[0] = 0b01000000
    check readPacket(datagram).short.spinBit == false
    datagram[0] = 0b01100000
    check readPacket(datagram).short.spinBit == true

  test "reads key phase from short packet":
    datagram[0] = 0b01000000
    check readPacket(datagram).short.keyPhase == false
    datagram[0] = 0b01000100
    check readPacket(datagram).short.keyPhase == true

  test "reads destination id from short packet":
    const destination = repeat(0xAB'u8, 16)
    datagram[0] = 0b01000000
    datagram[1..16] = destination
    check readPacket(datagram).destination == ConnectionId(destination)

  test "reads packet number from short packet":
    const packetnumber = 0xABCD'u16
    datagram[0] = 0b010000_01 # size of packetnumber is 2
    datagram[17..18] = packetnumber.toBytesBE
    let packet = readPacket(datagram)
    check packet.short.packetnumber == packetnumber

  test "reads payload from short packet":
    const payload = repeat(0xAB'u8, 1024)
    datagram[0] = 0b01000000
    datagram[18..1041] = payload
    let packet = readPacket(datagram[0..1041])
    check packet.short.payload == payload
