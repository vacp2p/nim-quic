import stew/endians2
import ../bits
import ../varints
import datagram
import packet

{.push raises:[].} # avoid exceptions in this module

type
  PacketReader* = object
    packet*: Packet
    first, next: int

proc peek(reader: var PacketReader, datagram: Datagram, amount: int): seq[byte] =
  datagram[reader.next..<reader.next+amount]

proc move(reader: var PacketReader, amount: int) =
  reader.next = reader.next + amount

proc read(reader: var PacketReader, datagram: Datagram, amount: int): seq[byte] =
  result = reader.peek(datagram, amount)
  reader.move(amount)

proc read(reader: var PacketReader, datagram: Datagram): byte =
  result = datagram[reader.next]
  reader.move(1)

proc readVarInt*(reader: var PacketReader, datagram: Datagram): VarIntCompatible =
  result = fromVarInt(datagram.toOpenArray(reader.next, datagram.len-1))
  reader.move(varintlen(datagram.toOpenArray(reader.next, datagram.len-1)))

proc readForm*(reader: var PacketReader, datagram: Datagram) =
  reader.packet = Packet(form: PacketForm(datagram[reader.next].bits[0]))

proc readFixedBit*(reader: var PacketReader, datagram: Datagram) =
  doAssert datagram[reader.next].bits[1] == 1

proc peekVersion*(reader: var PacketReader, datagram: Datagram): uint32 =
  fromBytesBE(uint32, reader.peek(datagram, 4))

proc readVersion*(reader: var PacketReader, datagram: Datagram) =
  reader.packet.version = fromBytesBE(uint32, reader.read(datagram, 4))

proc readSupportedVersion*(reader: var PacketReader, datagram: Datagram) =
  let version = fromBytesBE(uint32, reader.read(datagram, 4))
  reader.packet.negotiation.supportedVersion = version

proc readKind*(reader: var PacketReader, datagram: Datagram) =
  var kind: uint8
  kind.bits[6] = datagram[reader.next].bits[2]
  kind.bits[7] = datagram[reader.next].bits[3]
  reader.move(1)
  if reader.peekVersion(datagram) == 0:
    reader.packet = Packet(form: formLong, kind: packetVersionNegotiation)
  else:
    reader.packet = Packet(form: formLong, kind: PacketKind(kind))

proc readConnectionId*(reader: var PacketReader, datagram: Datagram): ConnectionId =
  let length = reader.read(datagram).int
  ConnectionId(reader.read(datagram, length))

proc readDestination*(reader: var PacketReader, datagram: Datagram) =
  reader.packet.destination = reader.readConnectionId(datagram)

proc readSource*(reader: var PacketReader, datagram: Datagram) =
  reader.packet.source = reader.readConnectionId(datagram)

proc readToken*(reader: var PacketReader, datagram: Datagram) =
  let length = datagram.len - 16 - reader.next
  reader.packet.retry.token = reader.read(datagram, length)

proc readIntegrity*(reader: var PacketReader, datagram: Datagram) =
  try:
    reader.packet.retry.integrity[0..<16] = reader.read(datagram, 16)
  except RangeError:
    doAssert false, "programmer error: assignment ranges do not match"

proc readPacketNumber*(reader: var PacketReader, datagram: Datagram) =
  let length = 1 + int(datagram[reader.first] and 0b11)
  let bytes = reader.read(datagram, length)
  var padded: array[4, byte]
  try:
    padded[padded.len-bytes.len..<padded.len] = bytes
  except RangeError:
    doAssert false, "programmer error: assignment ranges do not match"
  reader.packet.handshake.packetnumber = fromBytesBE(uint32, padded)

proc readPayload*(reader: var PacketReader, datagram: Datagram, length: int) =
  reader.packet.handshake.payload = reader.read(datagram, length)
