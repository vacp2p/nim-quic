import stew/endians2
import ../bits
import datagram
import packet

{.push raises:[].} # avoid exceptions in this module

proc readForm*(datagram: Datagram): PacketForm =
  PacketForm(datagram[0].bits[0])

proc readFixedBit*(datagram: Datagram) =
  doAssert datagram[0].bits[1] == 1

proc readVersion*(datagram: Datagram): uint32 =
  fromBytesBE(uint32, datagram[1..4])

proc readKind*(datagram: Datagram): PacketKind =
  if datagram.readVersion() == 0:
    packetVersionNegotiation
  else:
    var kind: uint8
    kind.bits[6] = datagram[0].bits[2]
    kind.bits[7] = datagram[0].bits[3]
    PacketKind(kind)

proc findDestination(datagram: Datagram): Slice[int] =
  let start = 6
  let length = datagram[5].int
  start..<start+length

proc findSource(datagram: Datagram): Slice[int] =
  let destinationEnd = datagram.findDestination().b + 1
  let start = destinationEnd + 1
  let length = datagram[destinationEnd].int
  start..<start+length

proc findSupportedVersion(datagram: Datagram): Slice[int] =
  let start = datagram.findSource().b + 1
  start..<start+4

proc readDestination*(datagram: Datagram): ConnectionId =
  ConnectionId(datagram[datagram.findDestination()])

proc readSource*(datagram: Datagram): ConnectionId =
  ConnectionId(datagram[datagram.findSource()])

proc readSupportedVersion*(datagram: Datagram): uint32 =
  let versionBytes = datagram[datagram.findSupportedVersion()]
  fromBytesBE(uint32, versionBytes)

proc readToken*(datagram: Datagram): seq[byte] =
  let start = datagram.findSource().b + 1
  let stop = datagram.len-16
  datagram[start..<stop]

proc readIntegrity*(datagram: Datagram): array[16, byte] =
  try:
    result[0..<16] = datagram[datagram.len-16..<datagram.len]
  except RangeError:
    doAssert false, "programmer error: assignment ranges do not match"
