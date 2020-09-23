import unittest
import math
import quic/varints

suite "variable length integer encoding":

  test "encodes 6 bit numbers as 1 byte":
    check toVarInt(0) == @[0'u8]
    check toVarInt(42) == @[42'u8]
    check toVarInt(63) == @[63'u8]

  test "encodes 7-14 bit numbers as 2 bytes":
    check toVarInt(64) == @[0b01000000'u8, 64'u8]
    check toVarInt(256) == @[0b01000001'u8, 0'u8]
    check toVarInt(2^14-1) == @[0b01111111'u8, 0xFF'u8]

  test "encodes 15-30 bit numbers as 4 bytes":
    check toVarInt(2^14) == @[0b10000000'u8, 0'u8, 0b01000000'u8, 0'u8]
    check toVarInt(2^16) == @[0b10000000'u8, 1'u8, 0'u8, 0'u8]
    check toVarInt(2^24) == @[0b10000001'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2^30-1) == @[0b10111111'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]

  test "encodes 30-62 bit numbers as 8 bytes":
    check toVarInt(2^30) ==
      @[0b11000000'u8, 0'u8, 0'u8, 0'u8, 0b01000000'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2^32) ==
      @[0b11000000'u8, 0'u8, 0'u8, 1'u8, 0'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2^56) ==
      @[0b11000001'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8]
    check toVarInt(2^62-1) ==
      @[0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]
