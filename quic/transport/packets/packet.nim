import ../../basics
import ../connectionid
import ../version
import ./packetnumber

export connectionid
export PacketNumber

type
  PacketForm* = enum
    formShort
    formLong

  PacketKind* = enum
    packetInitial
    packet0RTT
    packetHandshake
    packetRetry
    packetVersionNegotiation

  PacketShort* = object
    spinBit*: bool
    keyPhase*: bool
    packetnumber*: PacketNumber
    payload*: seq[byte]

  PacketInitial* = object
    version*: uint32
    token*: seq[byte]
    packetnumber*: PacketNumber
    payload*: seq[byte]

  Packet0RTT* = object
    version*: uint32
    packetnumber*: PacketNumber
    payload*: seq[byte]

  PacketHandshake* = object
    version*: uint32
    packetnumber*: PacketNumber
    payload*: seq[byte]

  PacketRetry* = object
    version*: uint32
    token*: seq[byte]
    integrity*: array[16, byte]

  PacketVersionNegotiation* = object
    supportedVersions*: seq[uint32]

  Packet* = object
    case form*: PacketForm
    of formShort:
      short*: PacketShort
    of formLong:
      case kind*: PacketKind
      of packetInitial:
        initial*: PacketInitial
      of packet0RTT:
        rtt*: Packet0RTT
      of packetHandshake:
        handshake*: PacketHandshake
      of packetRetry:
        retry*: PacketRetry
      of packetVersionNegotiation:
        negotiation*: PacketVersionNegotiation
      source*: ConnectionId
    destination*: ConnectionId

proc shortPacket*(): Packet =
  Packet(form: formShort)

proc initialPacket*(version = CurrentQuicVersion): Packet =
  result = Packet(form: formLong, kind: packetInitial)
  result.initial.version = version

proc zeroRttPacket*(version = CurrentQuicVersion): Packet =
  result = Packet(form: formLong, kind: packet0RTT)
  result.rtt.version = version

proc handshakePacket*(version = CurrentQuicVersion): Packet =
  result = Packet(form: formLong, kind: packetHandshake)
  result.handshake.version = version

proc retryPacket*(version = CurrentQuicVersion): Packet =
  result = Packet(form: formLong, kind: packetRetry)
  result.retry.version = version

proc versionNegotiationPacket*(versions = @[CurrentQuicVersion]): Packet =
  result = Packet(form: formLong, kind: packetVersionNegotiation)
  result.negotiation.supportedVersions = versions

proc `==`*(a, b: Packet): bool =
  if a.form != b.form:
    return false
  if a.destination != b.destination:
    return false
  case a.form
  of formShort:
    a.short == b.short
  of formLong:
    if a.kind != b.kind:
      return false
    if a.source != b.source:
      return false
    case a.kind
    of packetInitial:
      a.initial == b.initial
    of packet0RTT:
      a.retry == b.retry
    of packetHandshake:
      a.handshake == b.handshake
    of packetRetry:
      a.retry == b.retry
    of packetVersionNegotiation:
      a.negotiation == b.negotiation
