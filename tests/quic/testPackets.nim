import unittest
import math
import quic
import quic/bits

suite "packets":

  test "first bit of the header indicates its kind":
    check newPacketHeader(@[0b01000000'u8]).kind == headerShort
    check newPacketHeader(@[0b11000000'u8]).kind == headerLong

  test "header kind can be set":
    var header = newPacketHeader(@[0b01000000'u8])
    header.kind = headerLong
    check header.bytes[0].bits[0] == 1

  test "second bit of the header should always be 1":
    expect Exception:
      discard newPacketHeader(@[0b00000000'u8])

  test "packet numbers are in the range 0 to 2^62-1":
    check PacketNumber.low == 0
    check PacketNumber.high == 2'u64 ^ 62 - 1
