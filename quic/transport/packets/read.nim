import pkg/stew/endians2
import ../../basics
import ../../helpers/bits
import ./varints
import ./packet
import ./reader

export reader

proc readForm*(reader: var PacketReader, datagram: openArray[byte]) =
  reader.packet = Packet(form: PacketForm(datagram[reader.next].bits[0]))

proc readFixedBit*(reader: var PacketReader, datagram: openArray[byte]) =
  if datagram[reader.next].bits[1] != 1:
    raise newException(QuicError, "Unexpected fixed bit value")

proc peekVersion(reader: var PacketReader, datagram: openArray[byte]): uint32 =
  fromBytesBE(uint32, reader.peek(datagram, 4))

proc `version=`(packet: var Packet, version: uint32) =
  case packet.kind
  of packetInitial:
    packet.initial.version = version
  of packet0RTT:
    packet.rtt.version = version
  of packetHandshake:
    packet.handshake.version = version
  of packetRetry:
    packet.retry.version = version
  of packetVersionNegotiation:
    discard

proc readVersion*(reader: var PacketReader, datagram: openArray[byte]) =
  reader.packet.version = fromBytesBE(uint32, reader.read(datagram, 4))

proc readSupportedVersions*(reader: var PacketReader, datagram: openArray[byte]) =
  var versions: seq[uint32]
  while reader.next < datagram.len:
    versions.add(fromBytesBE(uint32, reader.read(datagram, 4)))
  reader.packet.negotiation.supportedVersions = versions

proc readKind*(reader: var PacketReader, datagram: openArray[byte]) =
  var kind: uint8
  kind.bits[6] = datagram[reader.next].bits[2]
  kind.bits[7] = datagram[reader.next].bits[3]
  reader.move(1)
  if reader.peekVersion(datagram) == 0:
    reader.packet = Packet(form: formLong, kind: packetVersionNegotiation)
  else:
    reader.packet = Packet(form: formLong, kind: PacketKind(kind))

proc readConnectionId(
    reader: var PacketReader, datagram: openArray[byte]
): ConnectionId =
  let length = reader.read(datagram).int
  ConnectionId(reader.read(datagram, length))

proc readDestination*(reader: var PacketReader, datagram: openArray[byte]) =
  reader.packet.destination = reader.readConnectionId(datagram)

proc readSource*(reader: var PacketReader, datagram: openArray[byte]) =
  reader.packet.source = reader.readConnectionId(datagram)

proc readRetryToken*(reader: var PacketReader, datagram: openArray[byte]) =
  let length = datagram.len - 16 - reader.next
  reader.packet.retry.token = reader.read(datagram, length)

proc readIntegrity*(reader: var PacketReader, datagram: openArray[byte]) =
  reader.packet.retry.integrity[0 ..< 16] = reader.read(datagram, 16)

proc readVarInt(reader: var PacketReader, datagram: openArray[byte]): VarIntCompatible =
  result = fromVarInt(datagram.toOpenArray(reader.next, datagram.len - 1))
  reader.move(varintlen(datagram.toOpenArray(reader.next, datagram.len - 1)))

proc `packetnumber=`(packet: var Packet, number: PacketNumber) =
  case packet.form
  of formShort:
    packet.short.packetnumber = number
  of formLong:
    case packet.kind
    of packetHandshake:
      packet.handshake.packetnumber = number
    of packet0RTT:
      packet.rtt.packetnumber = number
    of packetInitial:
      packet.initial.packetnumber = number
    else:
      discard

proc readPacketNumberLength(
    reader: var PacketReader, datagram: openArray[byte]
): range[1 .. 4] =
  1 + int(datagram[reader.first] and 0b11)

proc readPacketNumber(
    reader: var PacketReader, datagram: openArray[byte], length: range[1 .. 4]
) =
  let bytes = reader.read(datagram, length)
  var padded: array[4, byte]
  padded[padded.len - bytes.len ..< padded.len] = bytes
  reader.packet.packetnumber = fromBytesBE(uint32, padded).int64

proc `payload=`(packet: var Packet, payload: seq[byte]) =
  case packet.form
  of formShort:
    packet.short.payload = payload
  of formLong:
    case packet.kind
    of packetHandshake:
      packet.handshake.payload = payload
    of packet0RTT:
      packet.rtt.payload = payload
    of packetInitial:
      packet.initial.payload = payload
    else:
      discard

proc readPacketLength(reader: var PacketReader, datagram: openArray[byte]): int =
  case reader.packet.form
  of formLong:
    reader.readVarInt(datagram)
  of formShort:
    datagram.len - reader.next

proc readPayload(reader: var PacketReader, datagram: openArray[byte], length: int) =
  reader.packet.payload = reader.read(datagram, length)

proc readPacketNumberAndPayload*(reader: var PacketReader, datagram: openArray[byte]) =
  let length = reader.readPacketLength(datagram)
  let packetnumberLength = reader.readPacketNumberLength(datagram)
  let payloadLength = length - packetnumberLength
  reader.readPacketNumber(datagram, packetnumberLength)
  reader.readPayload(datagram, payloadLength.int)

proc readInitialToken*(reader: var PacketReader, datagram: openArray[byte]) =
  let length = reader.readVarInt(datagram)
  reader.packet.initial.token = reader.read(datagram, length.int)

proc readSpinBit*(reader: var PacketReader, datagram: openArray[byte]) =
  reader.packet.short.spinBit = bool(datagram[reader.next].bits[2])

proc readKeyPhase*(reader: var PacketReader, datagram: openArray[byte]) =
  reader.packet.short.keyPhase = bool(datagram[reader.next].bits[5])
  reader.move(1)

proc readShortDestination*(reader: var PacketReader, datagram: openArray[byte]) =
  const length = DefaultConnectionIdLength
  reader.packet.destination = ConnectionId(reader.read(datagram, length))
