import math
import strutils
import strformat
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
  FieldsInitial* = object
    version*: uint32
  Fields0RTT* = object
    version*: uint32
  FieldsHandshake* = object
    version*: uint32
  FieldsRetry* = object
    version*: uint32
  FieldsVersionNegotiation* = object
    supportedVersion*: uint32
  PacketHeader* = object
    case form*: PacketForm
    of formShort:
      discard
    of formLong:
      case kind*: PacketKind
      of packetInitial: initial*: FieldsInitial
      of packet0RTT: rtt*: Fields0RTT
      of packetHandshake: handshake*: FieldsHandshake
      of packetRetry: retry*: FieldsRetry
      of packetVersionNegotiation: negotiation*: FieldsVersionNegotiation
      destination*: ConnectionId
      source*: ConnectionId
    bytes: seq[byte]
  PacketNumber* = range[0'u64..2'u64^62-1]

proc readForm(datagram: seq[byte]): PacketForm =
  PacketForm(datagram[0].bits[0])

proc writeForm(datagram: var seq[byte], header: PacketHeader) =
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

proc version*(header: PacketHeader): uint32 =
  case header.kind
  of packetInitial: header.initial.version
  of packet0RTT: header.rtt.version
  of packetHandshake: header.handshake.version
  of packetRetry: header.retry.version
  of packetVersionNegotiation: 0

proc `version=`*(header: var PacketHeader, version: uint32) =
  case header.kind
  of packetInitial: header.initial.version = version
  of packet0RTT: header.rtt.version = version
  of packetHandshake: header.handshake.version = version
  of packetRetry: header.retry.version = version
  of packetVersionNegotiation: discard

proc writeVersion*(datagram: var seq[byte], header: PacketHeader) =
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

proc writeKind(datagram: var seq[byte], header: PacketHeader) =
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

proc newPacketHeader*(datagram: seq[byte]): PacketHeader =
  let form = datagram.readForm()
  datagram.readFixedBit()
  case form
  of formShort:
    result = PacketHeader(form: form, bytes: datagram)
  else:
    let kind = datagram.readKind()
    let destination = datagram.readDestination()
    let source = datagram.readSource()
    case kind
    of packetVersionNegotiation:
      let supportedVersion = datagram.readSupportedVersion()
      result = PacketHeader(form: form, kind: kind, destination: destination, source: source, negotiation: FieldsVersionNegotiation(supportedVersion: supportedVersion), bytes: datagram)
    else:
      result = PacketHeader(form: form, kind:kind, destination: destination, source: source, bytes: datagram)
      result.version = datagram.readVersion()

proc newShortPacketHeader*(): PacketHeader =
  PacketHeader(form: formShort)

proc write*(datagram: var seq[byte], header: PacketHeader) =
  datagram[0..<header.bytes.len] = header.bytes
  datagram.writeForm(header)
  datagram.writeFixedBit()
  if header.form == formLong:
    datagram.writeKind(header)
    datagram.writeVersion(header)

proc destinationSlice(header: PacketHeader): Slice[int] =
  let start = 6
  let length = header.bytes[5].int
  result = start..<start+length

proc sourceSlice(header: PacketHeader): Slice[int] =
  let destinationEnd = header.destinationSlice.b + 1
  let start = destinationEnd + 1
  let length = header.bytes[destinationEnd].int
  result = start..<start+length

proc supportedVersionSlice(header: PacketHeader): Slice[int] =
  let start = header.sourceSlice().b + 1
  result = start..<start+4

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

proc `$`*(header: PacketHeader): string =
  case header.form:
  of formShort:
    fmt"(form: {header.form})"
  else:
    case header.kind:
    of packetVersionNegotiation:
      "(" &
        fmt"kind: {header.kind}, " &
        fmt"destination: {header.destination}, " &
        fmt"source: {header.source}, " &
        fmt"supportedVersion: {header.negotiation.supportedVersion}" &
      ")"
    else:
      "(" &
        fmt"kind: {header.kind}, " &
        fmt"destination: {header.destination}, " &
        fmt"source: {header.source}" &
      ")"

proc `==`*(x: ConnectionId, y: ConnectionId): bool {.borrow.}

proc packetLength*(header: PacketHeader): int =
  case header.kind:
  of packetVersionNegotiation:
    return header.supportedVersionSlice.b + 1
  else:
    return 0
