import pkg/stew/endians2
import ../../helpers/bits
import ./varints
import ./packet
import ./packetnumber
import ./writer
export writer

proc writeForm*(writer: var PacketWriter, datagram: var openArray[byte]) =
  datagram[writer.next].bits[0] = Bit(writer.packet.form)

proc writeFixedBit*(writer: var PacketWriter, datagram: var openArray[byte]) =
  datagram[writer.next].bits[1] = 1

proc writeKind*(writer: var PacketWriter, datagram: var openArray[byte]) =
  let kind = writer.packet.kind
  case kind
  of packetVersionNegotiation:
    discard
  else:
    datagram[writer.next].bits[2] = kind.uint8.bits[6]
    datagram[writer.next].bits[3] = kind.uint8.bits[7]
  writer.move(1)

proc version(packet: Packet): uint32 =
  case packet.kind
  of packetInitial: packet.initial.version
  of packet0RTT: packet.rtt.version
  of packetHandshake: packet.handshake.version
  of packetRetry: packet.retry.version
  of packetVersionNegotiation: 0

proc writeVersion*(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.write(datagram, toBytesBE(writer.packet.version))

proc writeConnectionId(
    writer: var PacketWriter, datagram: var openArray[byte], id: ConnectionId
) =
  let bytes = cast[seq[byte]](id)
  writer.write(datagram, @[bytes.len.uint8] & bytes)

proc writeDestination*(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.writeConnectionId(datagram, writer.packet.destination)

proc writeSource*(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.writeConnectionId(datagram, writer.packet.source)

proc writeSupportedVersions*(writer: var PacketWriter, datagram: var openArray[byte]) =
  for version in writer.packet.negotiation.supportedVersions:
    writer.write(datagram, version.toBytesBE)

proc `token`(packet: Packet): seq[byte] =
  case packet.kind
  of packetInitial:
    packet.initial.token
  of packetRetry:
    packet.retry.token
  else:
    @[]

proc writeTokenLength*(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.write(datagram, writer.packet.token.len.toVarInt)

proc writeToken*(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.write(datagram, writer.packet.token)

proc writeIntegrity*(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.write(datagram, writer.packet.retry.integrity)

proc payload(packet: Packet): seq[byte] =
  case packet.form
  of formShort:
    packet.short.payload
  of formLong:
    case packet.kind
    of packetHandshake:
      packet.handshake.payload
    of packet0RTT:
      packet.rtt.payload
    of packetInitial:
      packet.initial.payload
    else:
      @[]

proc writePacketLength(
    writer: var PacketWriter, datagram: var openArray[byte], length: VarIntCompatible
) =
  case writer.packet.form
  of formLong:
    writer.write(datagram, length.toVarInt)
  of formShort:
    discard

proc packetNumber(packet: Packet): PacketNumber =
  case packet.form
  of formShort:
    packet.short.packetnumber
  of formLong:
    case packet.kind
    of packetHandshake: packet.handshake.packetnumber
    of packet0RTT: packet.rtt.packetnumber
    of packetInitial: packet.initial.packetnumber
    else: 0

proc writePacketNumber(
    writer: var PacketWriter,
    datagram: var openArray[byte],
    packetnumber: openArray[byte],
) =
  datagram[writer.first] = datagram[writer.first] or uint8(packetnumber.len - 1)
  writer.write(datagram, packetnumber)

proc writePacketNumberAndPayload*(
    writer: var PacketWriter, datagram: var openArray[byte]
) =
  let packetnumber = writer.packet.packetNumber.toMinimalBytes
  let payload = writer.packet.payload
  writer.writePacketLength(datagram, packetnumber.len + payload.len)
  writer.writePacketNumber(datagram, packetnumber)
  writer.write(datagram, payload)

proc writeSpinBit*(writer: var PacketWriter, datagram: var openArray[byte]) =
  datagram[writer.next].bits[2] = Bit(writer.packet.short.spinBit)

proc writeReservedBits*(writer: var PacketWriter, datagram: var openArray[byte]) =
  datagram[writer.next].bits[3] = 0
  datagram[writer.next].bits[4] = 0

proc writeKeyPhase*(writer: var PacketWriter, datagram: var openArray[byte]) =
  datagram[writer.next].bits[5] = Bit(writer.packet.short.keyPhase)
  writer.move(1)

proc writeShortDestination*(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.write(datagram, cast[seq[byte]](writer.packet.destination))
