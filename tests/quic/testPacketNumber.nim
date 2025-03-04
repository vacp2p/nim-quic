import pkg/unittest2
import std/math
import pkg/quic/transport/packets/packetnumber

suite "packet numbers":
  test "packet numbers are in the range 0 to 2^62-1":
    check PacketNumber.low == 0
    check PacketNumber.high == 2'i64 ^ 62 - 1

  test "conversion to bytes":
    check 0.toMinimalBytes == @[0'u8]
    check 0xFF.toMinimalBytes == @[0xFF'u8]
    check 0x01FF.toMinimalBytes == @[0x01'u8, 0xFF'u8]
    check 0xAABBCCDD.toMinimalBytes == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]
    check PacketNumber.high.toMinimalBytes ==
      @[0b00111111'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]
