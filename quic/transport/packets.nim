import ../basics
import ./packets/packet
import ./packets/length
import ./packets/read
import ./packets/write

export packet
export length

proc read(reader: var PacketReader, datagram: openArray[byte]): Packet =
  reader.readForm(datagram)
  reader.readFixedBit(datagram)
  case reader.packet.form
  of formShort:
    reader.readSpinBit(datagram)
    reader.readKeyPhase(datagram)
    reader.readShortDestination(datagram)
    reader.readPacketNumberAndPayload(datagram)
  of formLong:
    reader.readKind(datagram)
    reader.readVersion(datagram)
    reader.readDestination(datagram)
    reader.readSource(datagram)
    case reader.packet.kind
    of packetVersionNegotiation:
      reader.readSupportedVersions(datagram)
    of packetRetry:
      reader.readRetryToken(datagram)
      reader.readIntegrity(datagram)
    of packetHandshake, packet0RTT:
      reader.readPacketNumberAndPayload(datagram)
    of packetInitial:
      reader.readInitialToken(datagram)
      reader.readPacketNumberAndPayload(datagram)
  reader.packet

proc readPacket*(datagram: openArray[byte]): Packet =
  var reader = PacketReader()
  reader.read(datagram)

proc readPackets*(datagram: openArray[byte]): seq[Packet] =
  var reader = PacketReader()
  while reader.next < datagram.len:
    reader.nextPacket()
    result.add(reader.read(datagram))

proc write(writer: var PacketWriter, datagram: var openArray[byte]) =
  writer.writeForm(datagram)
  writer.writeFixedBit(datagram)
  case writer.packet.form
  of formShort:
    writer.writeSpinBit(datagram)
    writer.writeReservedBits(datagram)
    writer.writeKeyPhase(datagram)
    writer.writeShortDestination(datagram)
    writer.writePacketNumberAndPayload(datagram)
  of formLong:
    writer.writeKind(datagram)
    writer.writeVersion(datagram)
    writer.writeDestination(datagram)
    writer.writeSource(datagram)
    case writer.packet.kind
    of packetVersionNegotiation:
      writer.writeSupportedVersions(datagram)
    of packetRetry:
      writer.writeToken(datagram)
      writer.writeIntegrity(datagram)
    of packetHandshake, packet0RTT:
      writer.writePacketNumberAndPayload(datagram)
    of packetInitial:
      writer.writeTokenLength(datagram)
      writer.writeToken(datagram)
      writer.writePacketNumberAndPayload(datagram)

proc write*(datagram: var openArray[byte], packet: Packet): int {.discardable.} =
  var writer = PacketWriter(packet: packet)
  writer.write(datagram)
  writer.bytesWritten

proc write*(datagram: var openArray[byte], packets: seq[Packet]): int {.discardable.} =
  var writer = PacketWriter()
  for packet in packets:
    writer.nextPacket(packet)
    writer.write(datagram)
  writer.bytesWritten
