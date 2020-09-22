import stew/endians2
import datagram
import packet
import ../bits

proc writeForm*(datagram: var Datagram, header: Packet) =
  datagram[0].bits[0] = Bit(header.form)

proc writeFixedBit*(datagram: var Datagram) =
  datagram[0].bits[1] = 1

proc writeKind*(datagram: var Datagram, header: Packet) =
  case header.kind:
  of packetVersionNegotiation:
    discard
  else:
    datagram[0].bits[2] = header.kind.uint8.bits[6]
    datagram[0].bits[3] = header.kind.uint8.bits[7]

proc writeVersion*(datagram: var Datagram, header: Packet) =
  let bytes = toBytesBE(header.version)
  datagram[1] = bytes[0]
  datagram[2] = bytes[1]
  datagram[3] = bytes[2]
  datagram[4] = bytes[3]
