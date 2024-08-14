import pkg/chronos
import pkg/chronicles
import pkg/quic/transport/packets
import pkg/quic/transport/version
import pkg/quic/helpers/openarray

logScope:
  topics = "quic udp"

proc exampleQuicDatagram*: seq[byte] =
  var packet = initialPacket(CurrentQuicVersion)
  packet.destination = randomConnectionId()
  packet.source = randomConnectionId()
  result = newSeq[byte](4096)
  result.write(packet)

proc newDatagramTransport*: DatagramTransport =
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    discard
  newDatagramTransport(onReceive)

proc sendTo*(datagram: seq[byte], remote: TransportAddress) {.async.} =
  trace "Sending datagram", remote
  let udp = newDatagramTransport()
  await udp.sendTo(remote, datagram.toUnsafePtr, datagram.len)
  trace "Sent datagram", remote
  await udp.closeWait()
