import math
import strutils
import strformat
import bits

type
  PacketKind* = enum
    packetInitial
    packet0RTT
    packetHandshake
    packetRetry
    packetShort
    packetVersionNegotiation
  PacketHeader* = object
    case kind*: PacketKind
    of packetInitial, packet0RTT, packetHandshake, packetRetry:
      version*: uint32
    of packetShort:
      discard
    of packetVersionNegotiation:
      discard
    bytes: seq[byte]
  PacketNumber* = range[0'u64..2'u64^62-1]
  ConnectionId* = distinct seq[byte]

proc readVersion(datagram: seq[byte]): uint32 =
  result.bytes[0] = datagram[1]
  result.bytes[1] = datagram[2]
  result.bytes[2] = datagram[3]
  result.bytes[3] = datagram[4]

proc writeVersion*(datagram: var seq[byte], version: uint32) =
  datagram[1] = version.bytes[0]
  datagram[2] = version.bytes[1]
  datagram[3] = version.bytes[2]
  datagram[4] = version.bytes[3]

proc readKind(datagram: seq[byte]): PacketKind =
  if datagram[0].bits[0] == 0:
    result = packetShort
  elif datagram.readVersion() == 0:
    result = packetVersionNegotiation
  else:
    var kind: uint8
    kind.bits[6] = datagram[0].bits[2]
    kind.bits[7] = datagram[0].bits[3]
    result = PacketKind(kind)

proc writeKind(datagram: var seq[byte], kind: PacketKind) =
  case kind:
  of packetShort:
    datagram[0].bits[0] = 0
  else:
    datagram[0].bits[0] = 1
    case kind:
    of packetVersionNegotiation:
      datagram.writeVersion(0)
    else:
      datagram[0].bits[2] = kind.uint8.bits[6]
      datagram[0].bits[3] = kind.uint8.bits[7]

proc readFixedBit(datagram: seq[byte]) =
  assert datagram[0].bits[1] == 1

proc writeFixedBit(datagram: var seq[byte]) =
  datagram[0].bits[1] = 1

proc newPacketHeader*(datagram: seq[byte]): PacketHeader =
  datagram.readFixedBit()
  let kind = datagram.readKind()
  case kind
  of packetShort, packetVersionNegotiation:
    result = PacketHeader(kind: kind, bytes: datagram)
  else:
    let version = datagram.readVersion()
    result = PacketHeader(kind:kind, version: version, bytes: datagram)

proc newShortPacketHeader*(): PacketHeader =
  PacketHeader(kind: packetShort)

proc write*(datagram: var seq[byte], header: PacketHeader) =
  datagram[0..<header.bytes.len] = header.bytes
  datagram.writeFixedBit()
  datagram.writeKind(header.kind)
  case header.kind
  of packet0RTT, packetHandshake, packetInitial, packetRetry:
    datagram.writeVersion(header.version)
  else:
    discard

proc destinationSlice(header: PacketHeader): Slice[int] =
  let start = 6
  let length = header.bytes[5].int
  result = start..<start+length

proc sourceSlice(header: PacketHeader): Slice[int] =
  let destinationEnd = header.destinationSlice.b + 1
  let start = destinationEnd + 1
  let length = header.bytes[destinationEnd].int
  result = start..<start+length

proc destination*(header: PacketHeader): ConnectionId =
  result = ConnectionId(header.bytes[header.destinationSlice])

proc source*(header: PacketHeader): ConnectionId =
  result = ConnectionId(header.bytes[header.sourceSlice])

proc supportedVersionSlice(header: PacketHeader): Slice[int] =
  let start = header.sourceSlice().b + 1
  result = start..<start+4

proc supportedVersion*(header: PacketHeader): uint32 =
  let versionBytes = header.bytes[header.supportedVersionSlice]
  result.bytes[0] = versionBytes[0]
  result.bytes[1] = versionBytes[1]
  result.bytes[2] = versionBytes[2]
  result.bytes[3] = versionBytes[3]

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

proc `$`*(header: PacketHeader): string =
  case header.kind:
  of packetShort:
    fmt"(kind: {header.kind})"
  of packetVersionNegotiation:
    "(" &
      fmt"kind: {header.kind}, " &
      fmt"destination: {header.destination}, " &
      fmt"source: {header.source}, " &
      fmt"supportedVersion: {header.supportedVersion}" &
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
