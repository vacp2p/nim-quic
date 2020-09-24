import packets/datagram
import packets/packet
import packets/length
import packets/read
import packets/write
export datagram
export packet
export length

{.push raises:[].} # avoid exceptions in this module

proc readVersionNegotiation(packet: var Packet, datagram: Datagram) =
  packet.negotiation.supportedVersion = datagram.readSupportedVersion()

proc readRetry(packet: var Packet, datagram: Datagram) =
  packet.retry.token = datagram.readToken()
  packet.retry.integrity = datagram.readIntegrity()

proc readHandshake(packet: var Packet, datagram: Datagram) =
  packet.handshake.packetnumber = datagram.readPacketNumber()
  packet.handshake.payload = datagram.readPayload()

proc readLongPacket(datagram: Datagram): Packet =
  result = Packet(form: formLong, kind: datagram.readKind())
  result.destination = datagram.readDestination()
  result.source = datagram.readSource()
  result.version = datagram.readVersion()
  case result.kind
  of packetVersionNegotiation:
    result.readVersionNegotiation(datagram)
  of packetRetry:
    result.readRetry(datagram)
  of packetHandshake:
    result.readHandshake(datagram)
  else:
    discard

proc readPacket*(datagram: Datagram): Packet =
  let form = datagram.readForm()
  datagram.readFixedBit()
  case form
  of formShort:
    Packet(form: form)
  else:
    readLongPacket(datagram)

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
