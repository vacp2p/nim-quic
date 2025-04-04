import std/math
import pkg/stew/endians2

type PacketNumber* = range[0'i64 .. 2'i64 ^ 62 - 1]

proc toMinimalBytes*(packetnumber: PacketNumber): seq[byte] =
  let bytes = packetnumber.uint64.toBytesBE
  var length = bytes.len
  while length > 1 and bytes[bytes.len - length] == 0:
    length = length - 1
  bytes[bytes.len - length ..< bytes.len]
