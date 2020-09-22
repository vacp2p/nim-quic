import math
import strutils
import bits

{.push raises:[].} # avoid exceptions in this module

type
  ConnectionId* = distinct seq[byte]
  PacketForm* = enum
    formShort
    formLong
  PacketKind* = enum
    packetInitial
    packet0RTT
    packetHandshake
    packetRetry
    packetVersionNegotiation
  HeaderInitial* = object
    version*: uint32
  Header0RTT* = object
    version*: uint32
  HeaderHandshake* = object
    version*: uint32
  HeaderRetry* = object
    version*: uint32
  HeaderVersionNegotiation* = object
    supportedVersion*: uint32
  Packet* = object
    case form*: PacketForm
    of formShort:
      discard
    of formLong:
      case kind*: PacketKind
      of packetInitial: initial*: HeaderInitial
      of packet0RTT: rtt*: Header0RTT
      of packetHandshake: handshake*: HeaderHandshake
      of packetRetry: retry*: HeaderRetry
      of packetVersionNegotiation: negotiation*: HeaderVersionNegotiation
      destination*: ConnectionId
      source*: ConnectionId
  PacketNumber* = range[0'u64..2'u64^62-1]
  Datagram* = openArray[byte]

proc readForm(datagram: Datagram): PacketForm =
  PacketForm(datagram[0].bits[0])

proc writeForm(datagram: var Datagram, header: Packet) =
  datagram[0].bits[0] = Bit(header.form)

proc readFixedBit(datagram: Datagram) =
  doAssert datagram[0].bits[1] == 1

proc writeFixedBit(datagram: var Datagram) =
  datagram[0].bits[1] = 1

proc readVersion(datagram: Datagram): uint32 =
  result.bytes[0] = datagram[1]
  result.bytes[1] = datagram[2]
  result.bytes[2] = datagram[3]
  result.bytes[3] = datagram[4]

proc version*(header: Packet): uint32 =
  case header.kind
  of packetInitial: header.initial.version
  of packet0RTT: header.rtt.version
  of packetHandshake: header.handshake.version
  of packetRetry: header.retry.version
  of packetVersionNegotiation: 0

proc `version=`*(header: var Packet, version: uint32) =
  case header.kind
  of packetInitial: header.initial.version = version
  of packet0RTT: header.rtt.version = version
  of packetHandshake: header.handshake.version = version
  of packetRetry: header.retry.version = version
  of packetVersionNegotiation: discard

proc writeVersion*(datagram: var Datagram, header: Packet) =
  datagram[1] = header.version.bytes[0]
  datagram[2] = header.version.bytes[1]
  datagram[3] = header.version.bytes[2]
  datagram[4] = header.version.bytes[3]

proc readKind(datagram: Datagram): PacketKind =
  if datagram.readVersion() == 0:
    packetVersionNegotiation
  else:
    var kind: uint8
    kind.bits[6] = datagram[0].bits[2]
    kind.bits[7] = datagram[0].bits[3]
    PacketKind(kind)

proc writeKind(datagram: var Datagram, header: Packet) =
  case header.kind:
  of packetVersionNegotiation:
    discard
  else:
    datagram[0].bits[2] = header.kind.uint8.bits[6]
    datagram[0].bits[3] = header.kind.uint8.bits[7]

proc findDestination(datagram: Datagram): Slice[int] =
  let start = 6
  let length = datagram[5].int
  start..<start+length

proc readDestination*(datagram: Datagram): ConnectionId =
  ConnectionId(datagram[datagram.findDestination()])

proc findSource(datagram: Datagram): Slice[int] =
  let destinationEnd = datagram.findDestination().b + 1
  let start = destinationEnd + 1
  let length = datagram[destinationEnd].int
  start..<start+length

proc readSource(datagram: Datagram): ConnectionId =
  ConnectionId(datagram[datagram.findSource()])

proc findSupportedVersion(datagram: Datagram): Slice[int] =
  let start = datagram.findSource().b + 1
  start..<start+4

proc readSupportedVersion*(datagram: Datagram): uint32 =
  let versionBytes = datagram[datagram.findSupportedVersion()]
  result.bytes[0] = versionBytes[0]
  result.bytes[1] = versionBytes[1]
  result.bytes[2] = versionBytes[2]
  result.bytes[3] = versionBytes[3]

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

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

proc `==`*(x: ConnectionId, y: ConnectionId): bool {.borrow.}
proc `len`*(x: ConnectionId): int {.borrow.}

proc packetLength*(header: Packet): int =
  case header.kind:
  of packetVersionNegotiation:
    return 11 + header.destination.len + header.source.len
  else:
    return 0
