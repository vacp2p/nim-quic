import ./connectionid

type PacketInfo* = object
  source*, destination*: ConnectionId
  version*: uint32
