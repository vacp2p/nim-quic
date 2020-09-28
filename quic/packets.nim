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
      reader.readToken(datagram)
      reader.readIntegrity(datagram)
    of packetHandshake:
      let length = reader.readVarInt(datagram)
      reader.readPacketNumber(datagram)
      reader.readPayload(datagram, length.int)
    else:
      discard
  reader.packet

proc write*(datagram: var Datagram, packet: Packet) =
  var writer = PacketWriter(packet: packet)
  writer.writeForm(datagram)
  writer.writeFixedBit(datagram)
  if packet.form == formLong:
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
    of packetHandshake:
      writer.writePacketLength(datagram)
      writer.writePacketNumber(datagram)
      writer.writePayload(datagram)
    else:
      discard
