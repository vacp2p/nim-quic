import math
import bits

type
  HeaderForm* = enum
    headerShort
    headerLong
  PacketHeader* = object
    bytes: seq[byte]
  PacketNumber* = range[0'u64..2'u64^62-1]

proc newPacketHeader*(bytes: seq[byte]): PacketHeader =
  assert bytes[0].bits[1] == 1
  PacketHeader(bytes: bytes)

proc bytes*(header: PacketHeader): seq[byte] =
  header.bytes

proc form*(header: PacketHeader): HeaderForm =
  HeaderForm(header.bytes[0].bits[0])

proc `form=`*(header: var PacketHeader, form: HeaderForm) =
  header.bytes[0].bits[0] = Bit(form)

proc version*(header: PacketHeader): uint32 =
  result.bytes[0] = header.bytes[1]
  result.bytes[1] = header.bytes[2]
  result.bytes[2] = header.bytes[3]
  result.bytes[3] = header.bytes[4]

proc `version=`*(header: var PacketHeader, version: uint32) =
  header.bytes[1] = version.bytes[0]
  header.bytes[2] = version.bytes[1]
  header.bytes[3] = version.bytes[2]
  header.bytes[4] = version.bytes[3]
