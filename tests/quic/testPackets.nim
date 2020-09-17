import unittest
import math
import quic
import quic/bits

suite "packets":

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

  test "version negotiation packet is a packet with version 0":
    let header = newPacketHeader(@[0b01000000'u8, 0'u8, 0'u8, 0'u8, 0'u8])
    check header.kind == packetVersionNegotiation

  test "initial packet is a long packet of type 0":
    let header = newPacketHeader(@[0b11000000'u8, 0'u8, 0'u8, 0'u8, 1'u8])
    check header.kind == packetInitial

  test "0-RTT packet is a long packet of type 1":
    let header = newPacketHeader(@[0b11010000'u8, 0'u8, 0'u8, 0'u8, 1'u8])
    check header.kind == packet0RTT

  test "handshake packet is a long packet of type 2":
    let header = newPacketHeader(@[0b11100000'u8, 0'u8, 0'u8, 0'u8, 1'u8])
    check header.kind == packetHandshake

  test "retry packet is a long packet of type 3":
    let header = newPacketHeader(@[0b11110000'u8, 0'u8, 0'u8, 0'u8, 1'u8])
    check header.kind == packetRetry

  test "long packet type can be set":
    var header = newPacketHeader(@[0b11000000'u8, 0'u8, 0'u8, 0'u8, 1'u8])
    header.kind = packetHandshake
    check header.bytes[0].bits[2] == 1
    check header.bytes[0].bits[3] == 0

  test "packet numbers are in the range 0 to 2^62-1":
    check PacketNumber.low == 0
    check PacketNumber.high == 2'u64 ^ 62 - 1
