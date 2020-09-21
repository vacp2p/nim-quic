import unittest
import math
import quic
import quic/bits

suite "packet header":

  test "first bit of the header indicates its form":
    check newPacketHeader(@[0b01000000'u8]).form == headerShort
    check newPacketHeader(@[0b11000000'u8]).form == headerLong

  test "header form can be set":
    var header = newPacketHeader(@[0b01000000'u8])
    header.form = headerLong
    check header.bytes[0].bits[0] == 1

  test "second bit of the header should always be 1":
    expect Exception:
      discard newPacketHeader(@[0b00000000'u8])

  test "QUIC version is stored in bytes 1..4":
    var version = 0xAABBCCDD'u32
    var header = newPacketHeader(@[
      0b01000000'u8,
      version.bytes[0],
      version.bytes[1],
      version.bytes[2],
      version.bytes[3]
    ])
    check header.version == version

  test "QUIC version can be set":
    var header = newPacketHeader(@[0b01000000'u8, 0'u8, 0'u8, 0'u8, 0'u8])
    header.version = 0xAABBCCDD'u32
    check header.bytes[1..4] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

suite "short headers":

  test "conversion to string":
    check $newPacketHeader(@[0b01000000'u8]) == "(form: headerShort)"

suite "long headers":

  const type0 = @[0b11000000'u8]
  const type1 = @[0b11010000'u8]
  const type2 = @[0b11100000'u8]
  const type3 = @[0b11110000'u8]
  const version0 = @[0'u8, 0'u8, 0'u8, 0'u8]
  const version1 = @[0'u8, 0'u8, 0'u8, 1'u8]
  const destination = @[0xAA'u8, 0xBB'u8, 0xCC'u8]
  const source = @[0xDD'u8, 0xEE'u8, 0xFF'u8]

  test "version negotiation packet is a packet with version 0":
    let header = newPacketHeader(type0 & version0)
    check header.kind == packetVersionNegotiation

  test "initial packet is a long packet of type 0":
    let header = newPacketHeader(type0 & version1)
    check header.kind == packetInitial

  test "0-RTT packet is a long packet of type 1":
    let header = newPacketHeader(type1 & version1)
    check header.kind == packet0RTT

  test "handshake packet is a long packet of type 2":
    let header = newPacketHeader(type2 & version1)
    check header.kind == packetHandshake

  test "retry packet is a long packet of type 3":
    let header = newPacketHeader(type3 & version1)
    check header.kind == packetRetry

  test "long packet type can be set":
    var header = newPacketHeader(type0 & version1)
    header.kind = packetHandshake
    check header.bytes[0].bits[2] == 1
    check header.bytes[0].bits[3] == 0

  test "destination connection id is encoded from byte 5 onwards":
    let id = @[1'u8, 2'u8, 3'u8]
    var header = newPacketHeader(type0 & version1 & id.len.uint8 & id)
    check header.destination == ConnectionId(id)

  test "source connection id follows the destination connection id":
    var header = newPacketHeader(
      type0 & version1 &
      destination.len.uint8 & destination &
      source.len.uint8 & source
    )
    check header.source == ConnectionId(source)

  test "conversion to string":
    let header = $newPacketHeader(
      type0 &
      version0 &
      destination.len.uint8 & destination &
      source.len.uint8 & source
    )
    check $header == "(" &
      "form: headerLong, " &
      "kind: packetVersionNegotiation, " &
      "destination: 0xAABBCC, " &
      "source: 0xDDEEFF" &
    ")"

  suite "version negotiation packet":

    test "has a fixed length":
      let header = newPacketHeader(
        type0 &
        version0 &
        destination.len.uint8 & destination &
        source.len.uint8 & source &
        version1 &
        @[byte('r'), byte('e'), byte('s'), byte('t')]
      )
      check header.packetLength ==
        type0.len +
        version0.len +
        destination.len + 1 +
        source.len + 1 +
        version1.len

    test "has a supported version field":
      let header = newPacketHeader(
        type0 &
        version0 &
        destination.len.uint8 & destination &
        source.len.uint8 & source &
        version1
      )
      check header.supportedVersion == 1'u32

suite "packet numbers":

  test "packet numbers are in the range 0 to 2^62-1":
    check PacketNumber.low == 0
    check PacketNumber.high == 2'u64 ^ 62 - 1
