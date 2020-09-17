import math
import bits

type
  PacketHeaderKind* = enum
    headerShort
    headerLong
  PacketHeader* = object
    bytes*: seq[byte]
  PacketNumber* = range[0'u64..2'u64^62-1]

proc kind*(header: PacketHeader): PacketHeaderKind =
  PacketHeaderKind(header.bytes[0].bits[0])

proc `kind=`*(header: var PacketHeader, kind: PacketHeaderKind) =
  header.bytes[0].bits[0] = Bit(kind)
