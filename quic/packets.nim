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

proc readLongPacket(datagram: Datagram): Packet =
  let kind = datagram.readKind()
  case kind
  of packetVersionNegotiation:
    result = readVersionNegotiation(datagram)
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

proc write*(datagram: var Datagram, header: Packet) =
  datagram.writeForm(header)
  datagram.writeFixedBit()
  if header.form == formLong:
    datagram.writeKind(header)
    datagram.writeVersion(header)
