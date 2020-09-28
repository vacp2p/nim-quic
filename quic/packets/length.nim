import packet
import packetnumber
import ../varints

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
  of packetHandshake:
    return 7 +
      packet.destination.len +
      packet.source.len +
      packet.handshake.payload.len.toVarInt.len +
      packet.handshake.packetnumber.toMinimalBytes.len +
      packet.handshake.payload.len
  else:
    return 0
