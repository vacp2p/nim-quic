import math

type
  PacketHeaderKind* = enum
    headerShort
    headerLong
  PacketHeader* = object
    kind*: PacketHeaderKind

  PacketNumber* = range[0'u64..2'u64^62-1]
