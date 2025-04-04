import pkg/unittest2
import pkg/quic/helpers/bits

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
