import math
import strformat
import bits

type
  HeaderForm* = enum
    headerShort
    headerLong
  PacketKind* = enum
    packetInitial
    packet0RTT
    packetHandshake
    packetRetry
    packetVersionNegotiation
  PacketHeader* = object
    bytes: seq[byte]
  PacketNumber* = range[0'u64..2'u64^62-1]
  ConnectionId* = seq[byte]

proc newPacketHeader*(bytes: seq[byte]): PacketHeader =
  assert bytes[0].bits[1] == 1
  PacketHeader(bytes: bytes)

proc bytes*(header: PacketHeader): seq[byte] =
  header.bytes

proc form*(header: PacketHeader): HeaderForm =
  HeaderForm(header.bytes[0].bits[0])

proc `form=`*(header: var PacketHeader, form: HeaderForm) =
  header.bytes[0].bits[0] = Bit(form)

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
  if header.version == 0:
    result = packetVersionNegotiation
  else:
    var kind: uint8
    kind.bits[6] = header.bytes[0].bits[2]
    kind.bits[7] = header.bytes[0].bits[3]
    result = PacketKind(kind)

proc `kind=`*(header: var PacketHeader, kind: PacketKind) =
  header.bytes[0].bits[2] = kind.uint8.bits[6]
  header.bytes[0].bits[3] = kind.uint8.bits[7]

proc destination*(header: PacketHeader): ConnectionId =
  let length = header.bytes[5]
  result = header.bytes[6..<6+length]

proc source*(header: PacketHeader): ConnectionId =
  let destinationLength = header.bytes[5]
  let destinationEnd = 6+destinationLength
  let sourceLength = header.bytes[destinationEnd]
  let sourceStart = destinationEnd + 1
  result = header.bytes[sourceStart..<sourceStart+sourceLength]

proc `$`*(header: PacketHeader): string =
  case header.form:
  of headerShort: fmt"(form: {header.form})"
  of headerLong: "(" &
      fmt"form: {header.form}, " &
      fmt"kind: {header.kind}, " &
      fmt"destination: {header.destination}, " &
      fmt"source: {header.source}" &
    ")"
