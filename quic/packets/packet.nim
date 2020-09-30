import connectionid
import packetnumber
export connectionid
export PacketNumber
include ../noerrors

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
    supportedVersion*: uint32
  Packet* = object
    case form*: PacketForm
    of formShort:
      short*: PacketShort
    of formLong:
      case kind*: PacketKind
      of packetInitial: initial*: PacketInitial
      of packet0RTT: rtt*: Packet0RTT
      of packetHandshake: handshake*: PacketHandshake
      of packetRetry: retry*: PacketRetry
      of packetVersionNegotiation: negotiation*: PacketVersionNegotiation
      source*: ConnectionId
    destination*: ConnectionId
