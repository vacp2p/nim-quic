import unittest
import quic/bits

suite "bits":

  test "can index bits":
    let value = 0b10101010'u8
    check value.bits[0] == 1
    check value.bits[1] == 0
    check value.bits[2] == 1
    check value.bits[3] == 0
    check value.bits[4] == 1
    check value.bits[5] == 0
    check value.bits[6] == 1
    check value.bits[7] == 0

  test "can set bits":
    var value = 0b00000000'u8
    value.bits[0] = 1
    value.bits[3] = 1
    value.bits[7] = 1
    check value == 0b10010001'u8

  test "can clear bits":
    var value = 0b11111111'u8
    value.bits[0] = 0
    value.bits[3] = 0
    value.bits[7] = 0
    check value == 0b01101110'u8

suite "bytes":

  test "can index bytes":
    let value = 0xAABBCCDD'u32
    check value.bytes[0] == 0xAA
    check value.bytes[1] == 0xBB
    check value.bytes[2] == 0xCC
    check value.bytes[3] == 0xDD

  test "can set bytes":
    var value = 0x00000000'u32
    value.bytes[0] = 0xAA
    value.bytes[2] = 0xCC
    value.bytes[3] = 0xDD
    check value == 0xAA00CCDD'u32
