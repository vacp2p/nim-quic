import ./packet

type PacketReader* = object
  packet*: Packet
  first*, next*: int

proc peek*(
    reader: var PacketReader, datagram: openArray[byte], amount: int
): seq[byte] =
  datagram[reader.next ..< reader.next + amount]

proc move*(reader: var PacketReader, amount: int) =
  reader.next = reader.next + amount

proc read*(
    reader: var PacketReader, datagram: openArray[byte], amount: int
): seq[byte] =
  result = reader.peek(datagram, amount)
  reader.move(amount)

proc read*(reader: var PacketReader, datagram: openArray[byte]): byte =
  result = datagram[reader.next]
  reader.move(1)

proc nextPacket*(reader: var PacketReader) =
  reader.packet = Packet()
  reader.first = reader.next
