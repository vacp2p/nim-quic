import packets/datagram
import packets/packet
import packets/length
import packets/read
import packets/write
export datagram
export packet
export length

{.push raises:[].} # avoid exceptions in this module

proc readLongPacket(reader: var PacketReader, datagram: Datagram): Packet =
  result = Packet(form: formLong, kind: reader.readKind(datagram))
  result.version = reader.readVersion(datagram)
  result.destination = reader.readConnectionId(datagram)
  result.source = reader.readConnectionId(datagram)
  case result.kind
  of packetVersionNegotiation:
    result.negotiation.supportedVersion = reader.readVersion(datagram)
  of packetRetry:
    result.retry.token = reader.readToken(datagram)
    result.retry.integrity = reader.readIntegrity(datagram)
  of packetHandshake:
    let length = reader.readVarInt(datagram)
    result.handshake.packetnumber = reader.readPacketNumber(datagram)
    result.handshake.payload = reader.read(datagram, length.int)
  else:
    discard

proc readPacket*(datagram: Datagram): Packet =
  var reader = PacketReader()
  let form = reader.readForm(datagram)
  reader.readFixedBit(datagram)
  case form
  of formShort:
    Packet(form: form)
  else:
    readLongPacket(reader, datagram)

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
      writer.writePacketNumber(datagram)
    else:
      discard
