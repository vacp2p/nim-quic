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
  of packet0RTT:
    return 7 +
      packet.destination.len +
      packet.source.len +
      packet.rtt.payload.len.toVarInt.len +
      packet.rtt.packetnumber.toMinimalBytes.len +
      packet.rtt.payload.len
  of packetInitial:
    return 7 +
      packet.destination.len +
      packet.source.len +
      packet.initial.token.len.toVarInt.len +
      packet.initial.token.len +
      packet.initial.payload.len.toVarInt.len +
      packet.initial.packetnumber.toMinimalBytes.len +
      packet.initial.payload.len
