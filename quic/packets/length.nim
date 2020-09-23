import packet

{.push raises:[].} # avoid exceptions in this module

proc packetLength*(packet: Packet): int =
  case packet.kind:
  of packetVersionNegotiation:
    return 11 + packet.destination.len + packet.source.len
  else:
    return 0
