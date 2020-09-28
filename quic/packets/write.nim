import stew/endians2
import datagram
import packet
import packetnumber
import writer
import ../bits
import ../varints
export PacketWriter

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

proc `token`(packet: Packet): seq[byte] =
  case packet.kind
  of packetInitial: packet.initial.token
  of packetRetry: packet.retry.token
  else: @[]

proc writeTokenLength*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.token.len.toVarInt)

proc writeToken*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.token)

proc writeIntegrity*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.retry.integrity)

proc payload(packet: Packet): seq[byte] =
  case packet.kind
  of packetHandshake: packet.handshake.payload
  of packet0RTT: packet.rtt.payload
  of packetInitial: packet.initial.payload
  else: @[]

proc packetNumber(packet: Packet): PacketNumber =
  case packet.kind
  of packetHandshake: packet.handshake.packetnumber
  of packet0RTT: packet.rtt.packetnumber
  of packetInitial: packet.initial.packetnumber
  else: 0

proc writePacketLength*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.payload.len.toVarInt)

proc writePacketNumber*(writer: var PacketWriter, datagram: var Datagram) =
  let packetnumber = writer.packet.packetnumber
  let bytes = packetnumber.toMinimalBytes
  datagram[writer.first] = datagram[writer.first] or uint8(bytes.len - 1)
  writer.write(datagram, bytes)

proc writePayload*(writer: var PacketWriter, datagram: var Datagram) =
  writer.write(datagram, writer.packet.payload)

proc writeSpinBit*(writer: var PacketWriter, datagram: var Datagram) =
  datagram[writer.next].bits[2] = Bit(writer.packet.spinBit)

proc writeReservedBits*(writer: var PacketWriter, datagram: var Datagram) =
  datagram[writer.next].bits[3] = 0
  datagram[writer.next].bits[4] = 0
