import ./varints
import ./packet
import ./packetnumber

{.push raises: [].}

proc len*(packet: Packet): int =
  case packet.form
  of formShort:
    return
      1 + packet.destination.len + packet.short.packetnumber.toMinimalBytes.len +
      packet.short.payload.len
  of formLong:
    case packet.kind
    of packetVersionNegotiation:
      return
        7 + packet.destination.len + packet.source.len +
        packet.negotiation.supportedVersions.len * 4
    of packetRetry:
      return 23 + packet.destination.len + packet.source.len + packet.retry.token.len
    of packetHandshake:
      return
        7 + packet.destination.len + packet.source.len +
        packet.handshake.payload.len.toVarInt.len +
        packet.handshake.packetnumber.toMinimalBytes.len + packet.handshake.payload.len
    of packet0RTT:
      return
        7 + packet.destination.len + packet.source.len +
        packet.rtt.payload.len.toVarInt.len + packet.rtt.packetnumber.toMinimalBytes.len +
        packet.rtt.payload.len
    of packetInitial:
      return
        7 + packet.destination.len + packet.source.len +
        packet.initial.token.len.toVarInt.len + packet.initial.token.len +
        packet.initial.payload.len.toVarInt.len +
        packet.initial.packetnumber.toMinimalBytes.len + packet.initial.payload.len
