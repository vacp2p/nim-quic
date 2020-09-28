import packets/datagram
import packets/packet
import packets/length
import packets/read
import packets/write
export datagram
export packet
export length

{.push raises:[].} # avoid exceptions in this module

proc readPacket*(datagram: Datagram): Packet =
  var reader = PacketReader()
  reader.readForm(datagram)
  reader.readFixedBit(datagram)
  if reader.packet.form == formLong:
    reader.readKind(datagram)
    reader.readVersion(datagram)
    reader.readDestination(datagram)
    reader.readSource(datagram)
    case reader.packet.kind
    of packetVersionNegotiation:
      reader.readSupportedVersion(datagram)
    of packetRetry:
      reader.readRetryToken(datagram)
      reader.readIntegrity(datagram)
    of packetHandshake, packet0RTT:
      let length = reader.readVarInt(datagram)
      reader.readPacketNumber(datagram)
      reader.readPayload(datagram, length.int)
    of packetInitial:
      reader.readInitialToken(datagram)
      let length = reader.readVarInt(datagram)
      reader.readPacketNumber(datagram)
      reader.readPayload(datagram, length.int)
  reader.packet

proc write*(datagram: var Datagram, packet: Packet) =
  var writer = PacketWriter(packet: packet)
  writer.writeForm(datagram)
  writer.writeFixedBit(datagram)
  case packet.form
  of formShort:
    writer.writeSpinBit(datagram)
    writer.writeReservedBits(datagram)
    writer.writeKeyPhase(datagram)
    writer.writeShortDestination(datagram)
    writer.writePacketNumber(datagram)
    writer.writePayload(datagram)
  of formLong:
    writer.writeKind(datagram)
    writer.writeVersion(datagram)
    writer.writeDestination(datagram)
    writer.writeSource(datagram)
    case packet.kind
    of packetVersionNegotiation:
      writer.writeSupportedVersion(datagram)
    of packetRetry:
      writer.writeToken(datagram)
      writer.writeIntegrity(datagram)
    of packetHandshake, packet0RTT:
      writer.writePacketLength(datagram)
      writer.writePacketNumber(datagram)
      writer.writePayload(datagram)
    of packetInitial:
      writer.writeTokenLength(datagram)
      writer.writeToken(datagram)
      writer.writePacketLength(datagram)
      writer.writePacketNumber(datagram)
      writer.writePayload(datagram)
