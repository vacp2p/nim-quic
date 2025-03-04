import std/math
import pkg/stew/endians2

type VarIntCompatible* = range[0'i64 .. 2'i64 ^ 62 - 1]

proc toVarInt*(value: VarIntCompatible): seq[byte] =
  case value
  of 0 .. 2 ^ 6 - 1:
    @[value.uint8]
  of 2 ^ 6 .. 2 ^ 14 - 1:
    const length = 0b01'u16 shl 14
    @(toBytesBE(length or value.uint16))
  of 2 ^ 14 .. 2 ^ 30 - 1:
    const length = 0b10'u32 shl 30
    @(toBytesBE(length or value.uint32))
  else:
    const length = 0b11'u64 shl 62
    @(toBytesBE(length or value.uint64))

proc varintlen*(varint: openArray[byte]): int =
  2 ^ (varint[0] shr 6)

proc fromVarInt*(varint: openArray[byte]): VarIntCompatible =
  let r =
    case varintlen(varint)
    of 1:
      varint[0].uint64
    of 2:
      const mask = not (0b11'u16 shl 14)
      fromBytesBE(uint16, varint) and mask
    of 4:
      const mask = not (0b11'u32 shl 30)
      fromBytesBE(uint32, varint) and mask
    else:
      const mask = not (0b11'u64 shl 62)
      fromBytesBE(uint64, varint) and mask
  r.int64
