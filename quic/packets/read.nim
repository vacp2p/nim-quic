import stew/endians2
import ../bits
import ../varints
import datagram
import packet

{.push raises:[].} # avoid exceptions in this module

type
  PacketReader* = object
    first, next: int

proc peek(reader: var PacketReader, datagram: Datagram, amount: int): seq[byte] =
  datagram[reader.next..<reader.next+amount]

proc move(reader: var PacketReader, amount: int) =
  reader.next = reader.next + amount

proc read*(reader: var PacketReader, datagram: Datagram, amount: int): seq[byte] =
  result = reader.peek(datagram, amount)
  reader.move(amount)

proc read(reader: var PacketReader, datagram: Datagram): byte =
  result = datagram[reader.next]
  reader.move(1)

proc readVarInt*(reader: var PacketReader, datagram: Datagram): VarIntCompatible =
  result = fromVarInt(datagram.toOpenArray(reader.next, datagram.len-1))
  reader.move(varintlen(datagram.toOpenArray(reader.next, datagram.len-1)))

proc readForm*(reader: var PacketReader, datagram: Datagram): PacketForm =
  PacketForm(datagram[reader.next].bits[0])

proc readFixedBit*(reader: var PacketReader, datagram: Datagram) =
  doAssert datagram[reader.next].bits[1] == 1

proc peekVersion*(reader: var PacketReader, datagram: Datagram): uint32 =
  fromBytesBE(uint32, reader.peek(datagram, 4))

proc readVersion*(reader: var PacketReader, datagram: Datagram): uint32 =
  fromBytesBE(uint32, reader.read(datagram, 4))

proc readKind*(reader: var PacketReader, datagram: Datagram): PacketKind =
  var kind: uint8
  kind.bits[6] = datagram[reader.next].bits[2]
  kind.bits[7] = datagram[reader.next].bits[3]
  reader.move(1)
  if reader.peekVersion(datagram) == 0:
    packetVersionNegotiation
  else:
    PacketKind(kind)

proc readConnectionId*(reader: var PacketReader, datagram: Datagram): ConnectionId =
  let length = reader.read(datagram).int
  ConnectionId(reader.read(datagram, length))

proc readToken*(reader: var PacketReader, datagram: Datagram): seq[byte] =
  let length = datagram.len - 16 - reader.next
  reader.read(datagram, length)

proc readIntegrity*(reader: var PacketReader, datagram: Datagram): array[16, byte] =
  try:
    result[0..<16] = reader.read(datagram, 16)
  except RangeError:
    doAssert false, "programmer error: assignment ranges do not match"

proc readPacketNumber*(reader: var PacketReader, datagram: Datagram): PacketNumber =
  let length = 1 + int(datagram[reader.first] and 0b11)
  let bytes = reader.read(datagram, length)
  var padded: array[8, byte]
  try:
    padded[padded.len-bytes.len..<padded.len] = bytes
  except RangeError:
    doAssert false, "programmer error: assignment ranges do not match"
  fromBytesBE(uint64, padded)
