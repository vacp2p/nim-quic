import packet
import datagram

type
  PacketReader* = object
    packet*: Packet
    first*, next*: int

proc peek*(reader: var PacketReader, datagram: Datagram, amount: int): seq[byte] =
  datagram[reader.next..<reader.next+amount]

proc move*(reader: var PacketReader, amount: int) =
  reader.next = reader.next + amount

proc read*(reader: var PacketReader, datagram: Datagram, amount: int): seq[byte] =
  result = reader.peek(datagram, amount)
  reader.move(amount)

proc read*(reader: var PacketReader, datagram: Datagram): byte =
  result = datagram[reader.next]
  reader.move(1)

