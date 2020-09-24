import packets/datagram
import packets/packet
import packets/length
import packets/read
import packets/write
export datagram
export packet
export length

{.push raises:[].} # avoid exceptions in this module

proc readVersionNegotiation(datagram: Datagram): Packet =
  Packet(
    form: formLong,
    kind: packetVersionNegotiation,
    destination: datagram.readDestination(),
    source: datagram.readSource(),
    negotiation: HeaderVersionNegotiation(
      supportedVersion: datagram.readSupportedVersion()
    )
  )

proc readRetry(datagram: Datagram): Packet =
  result = Packet(
    form: formLong,
    kind: packetRetry,
    destination: datagram.readDestination(),
    source: datagram.readSource(),
    retry: HeaderRetry(
      token: datagram.readToken(),
      integrity: datagram.readIntegrity()
    )
  )

proc readLongPacket(datagram: Datagram): Packet =
  let kind = datagram.readKind()
  case kind
  of packetVersionNegotiation:
    result = readVersionNegotiation(datagram)
  of packetRetry:
    result = readRetry(datagram)
  else:
    result = Packet(
      form: formLong,
      kind:kind,
      destination: datagram.readDestination(),
      source: datagram.readSource()
    )
    result.version = datagram.readVersion()

proc readPacket*(datagram: Datagram): Packet =
  let form = datagram.readForm()
  datagram.readFixedBit()
  case form
  of formShort:
    Packet(form: form)
  else:
    readLongPacket(datagram)

proc write*(datagram: var Datagram, packet: Packet) =
  datagram.writeForm(packet)
  datagram.writeFixedBit()
  if packet.form == formLong:
    datagram.writeKind(packet)
    datagram.writeVersion(packet)
    datagram.writeDestination(packet)
    datagram.writeSource(packet)
    if packet.kind == packetVersionNegotiation:
      datagram.writeSupportedVersion(packet)
    if packet.kind == packetRetry:
      datagram.writeToken(packet)
      datagram.writeIntegrity(packet)
