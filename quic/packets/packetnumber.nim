import std/math
import stew/endians2

type
  PacketNumber* = range[0'u64..2'u64^62-1]

proc toMinimalBytes*(packetnumber: PacketNumber): seq[byte] =
  let bytes = packetnumber.toBytesBE
  var length = bytes.len
  while length > 1 and bytes[bytes.len - length] == 0:
    length = length - 1
  bytes[bytes.len-length..<bytes.len]
