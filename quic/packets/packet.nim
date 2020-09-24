import math
import connectionid
export connectionid

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
  HeaderInitial* = object
    version*: uint32
  Header0RTT* = object
    version*: uint32
  HeaderHandshake* = object
    version*: uint32
    packetnumber*: PacketNumber
    payload*: seq[byte]
  HeaderRetry* = object
    version*: uint32
    token*: seq[byte]
    integrity*: array[16, byte]
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
