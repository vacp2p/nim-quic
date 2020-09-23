import math
import stew/endians2

type
  VarIntCompatible* = range[0'u64..2'u64^62-1]
  VarInt* = seq[byte]

proc toVarInt*(value: VarIntCompatible): VarInt =
  case value
  of 0..2^6-1:
    @[value.uint8]
  of 2^6..2^14-1:
    const length = 0b01'u16 shl 14
    @(toBytesBE(length or value.uint16))
  of 2^14..2^30-1:
    const length = 0b10'u32 shl 30
    @(toBytesBE(length or value.uint32))
  else:
    const length = 0b11'u64 shl 62
    @(toBytesBE(length or value))
