import stew/endians2
import datagram
import packet
import ../bits

proc writeForm*(datagram: var Datagram, packet: Packet) =
  datagram[0].bits[0] = Bit(packet.form)

proc writeFixedBit*(datagram: var Datagram) =
  datagram[0].bits[1] = 1

proc writeKind*(datagram: var Datagram, packet: Packet) =
  case packet.kind:
  of packetVersionNegotiation:
    discard
  else:
    datagram[0].bits[2] = packet.kind.uint8.bits[6]
    datagram[0].bits[3] = packet.kind.uint8.bits[7]

proc writeVersion*(datagram: var Datagram, packet: Packet) =
  let bytes = toBytesBE(packet.version)
  datagram[1] = bytes[0]
  datagram[2] = bytes[1]
  datagram[3] = bytes[2]
  datagram[4] = bytes[3]
