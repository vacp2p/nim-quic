import ../../helpers/openarray
import ./packet

type PacketWriter* = object
  packet*: Packet
  first*, next*: int

proc move*(writer: var PacketWriter, amount: int) =
  writer.next = writer.next + amount

proc write*(
    writer: var PacketWriter, datagram: var openArray[byte], bytes: openArray[byte]
) =
  datagram[writer.next ..< writer.next + bytes.len] = bytes
  writer.move(bytes.len)

proc nextPacket*(writer: var PacketWriter, packet: Packet) =
  writer.packet = packet
  writer.first = writer.next

proc bytesWritten*(writer: PacketWriter): int =
  writer.next
