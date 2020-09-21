import math
import strutils
import bits

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

proc readForm(datagram: seq[byte]): PacketForm =
  PacketForm(datagram[0].bits[0])

proc writeForm(datagram: var seq[byte], header: Packet) =
  datagram[0].bits[0] = Bit(header.form)

proc readFixedBit(datagram: seq[byte]) =
  assert datagram[0].bits[1] == 1

proc writeFixedBit(datagram: var seq[byte]) =
  datagram[0].bits[1] = 1

proc readVersion(datagram: seq[byte]): uint32 =
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

proc writeVersion*(datagram: var seq[byte], header: Packet) =
  datagram[1] = header.version.bytes[0]
  datagram[2] = header.version.bytes[1]
  datagram[3] = header.version.bytes[2]
  datagram[4] = header.version.bytes[3]

proc readKind(datagram: seq[byte]): PacketKind =
  if datagram.readVersion() == 0:
    result = packetVersionNegotiation
  else:
    var kind: uint8
    kind.bits[6] = datagram[0].bits[2]
    kind.bits[7] = datagram[0].bits[3]
    result = PacketKind(kind)

proc writeKind(datagram: var seq[byte], header: Packet) =
  case header.kind:
  of packetVersionNegotiation:
    discard
  else:
    datagram[0].bits[2] = header.kind.uint8.bits[6]
    datagram[0].bits[3] = header.kind.uint8.bits[7]

proc findDestination(datagram: seq[byte]): Slice[int] =
  let start = 6
  let length = datagram[5].int
  result = start..<start+length

proc readDestination*(datagram: seq[byte]): ConnectionId =
  result = ConnectionId(datagram[datagram.findDestination()])

proc findSource(datagram: seq[byte]): Slice[int] =
  let destinationEnd = datagram.findDestination().b + 1
  let start = destinationEnd + 1
  let length = datagram[destinationEnd].int
  result = start..<start+length

proc readSource(datagram: seq[byte]): ConnectionId =
  result = ConnectionId(datagram[datagram.findSource()])

proc findSupportedVersion(datagram: seq[byte]): Slice[int] =
  let start = datagram.findSource().b + 1
  result = start..<start+4

proc readSupportedVersion*(datagram: seq[byte]): uint32 =
  let versionBytes = datagram[datagram.findSupportedVersion()]
  result.bytes[0] = versionBytes[0]
  result.bytes[1] = versionBytes[1]
  result.bytes[2] = versionBytes[2]
  result.bytes[3] = versionBytes[3]

proc newVersionNegotiation(datagram: seq[byte]): Packet =
  result = Packet(
    form: formLong,
    kind: packetVersionNegotiation,
    destination: datagram.readDestination(),
    source: datagram.readSource(),
    negotiation: HeaderVersionNegotiation(
      supportedVersion: datagram.readSupportedVersion()
    )
  )

proc newLongPacket(datagram: seq[byte]): Packet =
  let kind = datagram.readKind()
  case kind
  of packetVersionNegotiation:
    result = newVersionNegotiation(datagram)
  else:
    result = Packet(
      form: formLong,
      kind:kind,
      destination: datagram.readDestination(),
      source: datagram.readSource()
    )
    result.version = datagram.readVersion()

proc newPacket*(datagram: seq[byte]): Packet =
  let form = datagram.readForm()
  datagram.readFixedBit()
  case form
  of formShort:
    result = Packet(form: form)
  else:
    result = newLongPacket(datagram)

proc newShortPacket*(): Packet =
  Packet(form: formShort)

proc write*(datagram: var seq[byte], header: Packet) =
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
