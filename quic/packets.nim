type
  PacketHeaderKind* = enum
    headerShort
    headerLong
  PacketHeader* = object
    kind*: PacketHeaderKind
