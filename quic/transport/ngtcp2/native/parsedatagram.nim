import pkg/ngtcp2
import ../../../helpers/[openarray, sequninit]
import ../../packetinfo
import ../../connectionid
import ./errors

proc toConnectionId(p: ptr byte, length: uint): ConnectionId =
  var bytes = newSeqUninit[byte](length)
  copyMem(bytes.toPtr, p, length)
  ConnectionId(bytes)

proc parseDatagramInfo*(datagram: openArray[byte]): PacketInfo =
  var version: ngtcp2_version_cid
  checkResult ngtcp2_pkt_decode_version_cid(
    addr version, unsafeAddr datagram[0], datagram.len.uint, DefaultConnectionIdLength
  )
  PacketInfo(
    source: toConnectionId(version.scid, version.scidlen),
    destination: toConnectionId(version.dcid, version.dcidlen),
    version: version.version.uint32,
  )

proc parseDatagramDestination*(datagram: openArray[byte]): ConnectionId =
  var version: ngtcp2_version_cid
  checkResult ngtcp2_pkt_decode_version_cid(
    addr version, unsafeAddr datagram[0], datagram.len.uint, DefaultConnectionIdLength
  )
  return toConnectionId(version.dcid, version.dcidlen)

proc shouldAccept*(datagram: openArray[byte]): bool =
  var hd: ngtcp2_pkt_hd
  let ret = ngtcp2_accept(hd.unsafeAddr, datagram[0].unsafeAddr, datagram.len.uint)
  return ret == 0
