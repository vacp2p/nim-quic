import pkg/ngtcp2
import ../../../helpers/openarray
import ../../packetinfo
import ../../connectionid
import ./errors

proc toConnectionId(p: ptr byte, length: uint): ConnectionId =
  var bytes = newSeqUninitialized[byte](length)
  copyMem(bytes.toPtr, p, length)
  ConnectionId(bytes)

proc parseDatagram*(datagram: openArray[byte]): PacketInfo =
  var version: ngtcp2_version_cid;
  checkResult ngtcp2_pkt_decode_version_cid(
    addr version,
    unsafeAddr datagram[0],
    datagram.len.uint,
    DefaultConnectionIdLength
  )
  PacketInfo(
    source: toConnectionId(version.scid, version.scidlen),
    destination: toConnectionId(version.dcid, version.dcidlen),
    version: version.version.uint32
  )
