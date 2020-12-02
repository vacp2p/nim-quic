import pkg/ngtcp2
import ../connectionid
import ../openarray
import ./errors

type
  PacketInfo = object
    source*, destination*: ConnectionId
    version*: uint32

proc toConnectionId(p: ptr byte, length: uint): ConnectionId =
  var bytes = newSeqUninitialized[byte](length)
  copyMem(bytes.toPtr, p, length)
  ConnectionId(bytes)

proc parseDatagram*(datagram: openArray[byte]): PacketInfo =
  var version: uint32
  var destinationId: ptr uint8
  var destinationIdLen: uint
  var sourceId: ptr uint8
  var sourceIdLen: uint
  checkResult ngtcp2_pkt_decode_version_cid(
    addr version,
    addr destinationId,
    addr destinationIdLen,
    addr sourceId,
    addr sourceIdLen,
    unsafeAddr datagram[0],
    datagram.len.uint,
    DefaultConnectionIdLength
  )
  PacketInfo(
    source: toConnectionId(sourceId, sourceIdLen),
    destination: toConnectionId(destinationId, destinationIdLen),
    version: version
  )
