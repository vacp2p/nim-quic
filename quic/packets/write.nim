import stew/endians2
import datagram
import packet
import packetnumber
import ../bits
import ../openarray

type
  PacketWriter* = object
    packet*: Packet
    first, next: int

proc move(writer: var PacketWriter, amount: int) =
  writer.next = writer.next + amount

proc write(writer: var PacketWriter, datagram: var Datagram, bytes: openArray[byte]) =
  datagram[writer.next..<writer.next+bytes.len] = bytes
  writer.move(bytes.len)

proc writeForm*(writer: var PacketWriter, datagram: var Datagram) =
  datagram[writer.next].bits[0] = Bit(writer.packet.form)

proc writeFixedBit*(writer: var PacketWriter, datagram: var Datagram) =
  datagram[writer.next].bits[1] = 1

proc writeKind*(writer: var PacketWriter, datagram: var Datagram) =
  let kind = writer.packet.kind
  case kind:
  of packetVersionNegotiation:
    discard
  else:
    datagram[writer.next].bits[2] = kind.uint8.bits[6]
    datagram[writer.next].bits[3] = kind.uint8.bits[7]
  writer.move(1)

proc writeVersion*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, toBytesBE(writer.packet.version))

proc writeConnectionId(writer: var PacketWriter, datagram: var Datagram, id: ConnectionId) =
  let bytes = cast[seq[byte]](id)
  writer.write(datagram, @[bytes.len.uint8] & bytes)

proc writeDestination*(writer: var PacketWriter, datagram: var Datagram) =
  writer.writeConnectionId(datagram, writer.packet.destination)

proc writeSource*(writer: var PacketWriter, datagram: var Datagram) =
  writer.writeConnectionId(datagram, writer.packet.source)

proc writeSupportedVersion*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.negotiation.supportedVersion.toBytesBE)

proc writeToken*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.retry.token)

proc writeIntegrity*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.retry.integrity)

proc writePacketNumber*(writer: var PacketWriter, datagram: var Datagram) =
  let packetnumber = writer.packet.handshake.packetnumber
  let bytes = packetnumber.toMinimalBytes
  datagram[writer.first] = datagram[writer.first] or uint8(bytes.len - 1)
  writer.move(1) # skip payload length for now
  writer.write(datagram, bytes)
