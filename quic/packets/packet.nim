import connectionid
import packetnumber
export connectionid
export PacketNumber

{.push raises:[].} # avoid exceptions in this module

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
    supportedVersion*: uint32
  Packet* = object
    case form*: PacketForm
    of formShort:
      spinBit*: bool
    of formLong:
      case kind*: PacketKind
      of packetInitial: initial*: PacketInitial
      of packet0RTT: rtt*: Packet0RTT
      of packetHandshake: handshake*: PacketHandshake
      of packetRetry: retry*: PacketRetry
      of packetVersionNegotiation: negotiation*: PacketVersionNegotiation
      destination*: ConnectionId
      source*: ConnectionId

proc version*(packet: Packet): uint32 =
  case packet.kind
  of packetInitial: packet.initial.version
  of packet0RTT: packet.rtt.version
  of packetHandshake: packet.handshake.version
  of packetRetry: packet.retry.version
  of packetVersionNegotiation: 0

proc `version=`*(packet: var Packet, version: uint32) =
  case packet.kind
  of packetInitial: packet.initial.version = version
  of packet0RTT: packet.rtt.version = version
  of packetHandshake: packet.handshake.version = version
  of packetRetry: packet.retry.version = version
  of packetVersionNegotiation: discard
