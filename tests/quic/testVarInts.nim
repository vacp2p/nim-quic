import std/math
import pkg/unittest2
import pkg/quic/transport/packets/varints

suite "variable length integer encoding":
  test "encodes 6 bit numbers as 1 byte":
    check toVarInt(0) == @[0'u8]
    check toVarInt(42) == @[42'u8]
    check toVarInt(63) == @[63'u8]

  test "encodes 7-14 bit numbers as 2 bytes":
    check toVarInt(64) == @[0b01000000'u8, 64'u8]
    check toVarInt(256) == @[0b01000001'u8, 0'u8]
    check toVarInt(2 ^ 14 - 1) == @[0b01111111'u8, 0xFF'u8]

  test "encodes 15-30 bit numbers as 4 bytes":
    check toVarInt(2 ^ 14) == @[0b10000000'u8, 0'u8, 0b01000000'u8, 0'u8]
    check toVarInt(2 ^ 16) == @[0b10000000'u8, 1'u8, 0'u8, 0'u8]
    check toVarInt(2 ^ 24) == @[0b10000001'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2 ^ 30 - 1) == @[0b10111111'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]

  test "encodes 30-62 bit numbers as 8 bytes":
    check toVarInt(2 ^ 30) ==
      @[0b11000000'u8, 0'u8, 0'u8, 0'u8, 0b01000000'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2'i64 ^ 32) ==
      @[0b11000000'u8, 0'u8, 0'u8, 1'u8, 0'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2'i64 ^ 56) ==
      @[0b11000001'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2'i64 ^ 62 - 1) ==
      @[0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]

suite "variable length integer decoding":
  test "decodes 1 byte integers":
    check fromVarInt(@[0'u8]) == 0
    check fromVarInt(@[42'u8]) == 42
    check fromVarInt(@[63'u8]) == 63

  test "decodes 2 byte integers":
    check fromVarInt(@[0b01000000'u8, 0'u8]) == 0
    check fromVarInt(@[0b01000001'u8, 0'u8]) == 256
    check fromVarInt(@[0b01111111'u8, 0xFF'u8]) == 2 ^ 14 - 1

  test "decodes 4 byte integers":
    check fromVarInt(@[0b10000000'u8, 0'u8, 0'u8, 0'u8]) == 0
    check fromVarInt(@[0b10000001'u8, 0'u8, 0'u8, 0'u8]) == 2 ^ 24
    check fromVarInt(@[0b10111111'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]) == 2 ^ 30 - 1

  test "decodes 8 byte integers":
    check fromVarInt(@[0b11000000'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8]) == 0
    check fromVarInt(@[0b11000001'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8]) ==
      2'i64 ^ 56
    check fromVarInt(
      @[0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]
    ) == 2'i64 ^ 62 - 1

suite "variable length":
  test "determines length correctly":
    var buffer: array[8, byte]
    buffer[0] = 0b00000000'u8
    check varintlen(buffer) == 1
    buffer[0] = 0b01000000'u8
    check varintlen(buffer) == 2
    buffer[0] = 0b10000000'u8
    check varintlen(buffer) == 4
    buffer[0] = 0b11000000'u8
    check varintlen(buffer) == 8
