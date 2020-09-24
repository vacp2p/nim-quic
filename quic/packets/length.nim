import packet

{.push raises:[].} # avoid exceptions in this module

proc len*(packet: Packet): int =
  case packet.kind:
  of packetVersionNegotiation:
    return 11 +
      packet.destination.len +
      packet.source.len
  of packetRetry:
    return 23 +
      packet.destination.len +
      packet.source.len +
      packet.retry.token.len
  else:
    return 0
