import packet
import datagram
import ../openarray

type
  PacketWriter* = object
    packet*: Packet
    first*, next*: int

proc move*(writer: var PacketWriter, amount: int) =
  writer.next = writer.next + amount

proc write*(writer: var PacketWriter, datagram: var Datagram, bytes: openArray[byte]) =
  datagram[writer.next..<writer.next+bytes.len] = bytes
  writer.move(bytes.len)

