import packet

{.push raises:[].} # avoid exceptions in this module

proc packetLength*(header: Packet): int =
  case header.kind:
  of packetVersionNegotiation:
    return 11 + header.destination.len + header.source.len
  else:
    return 0
