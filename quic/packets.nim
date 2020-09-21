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
    bytes: seq[byte]
  PacketNumber* = range[0'u64..2'u64^62-1]
  ConnectionId* = distinct seq[byte]

proc newPacketHeader*(bytes: seq[byte]): PacketHeader =
  assert bytes[0].bits[1] == 1
  PacketHeader(bytes: bytes)

proc bytes*(header: PacketHeader): seq[byte] =
  header.bytes

proc version*(header: PacketHeader): uint32 =
  result.bytes[0] = header.bytes[1]
  result.bytes[1] = header.bytes[2]
  result.bytes[2] = header.bytes[3]
  result.bytes[3] = header.bytes[4]

proc `version=`*(header: var PacketHeader, version: uint32) =
  header.bytes[1] = version.bytes[0]
  header.bytes[2] = version.bytes[1]
  header.bytes[3] = version.bytes[2]
  header.bytes[4] = version.bytes[3]

proc kind*(header: PacketHeader): PacketKind =
  if header.bytes[0].bits[0] == 0:
    result = packetShort
  elif header.version == 0:
    result = packetVersionNegotiation
  else:
    var kind: uint8
    kind.bits[6] = header.bytes[0].bits[2]
    kind.bits[7] = header.bytes[0].bits[3]
    result = PacketKind(kind)

proc `kind=`*(header: var PacketHeader, kind: PacketKind) =
  header.bytes[0].bits[2] = kind.uint8.bits[6]
  header.bytes[0].bits[3] = kind.uint8.bits[7]

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
