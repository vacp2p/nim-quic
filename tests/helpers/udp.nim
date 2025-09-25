import chronos
import chronicles
import quic/transport/[packets, version]
import quic/helpers/[openarray, rand]

logScope:
  topics = "quic udp"

proc exampleQuicDatagram*(): seq[byte] =
  var packet = initialPacket(CurrentQuicVersion)
  let rng = newRng()
  packet.destination = randomConnectionId(rng)
  packet.source = randomConnectionId(rng)
  result = newSeq[byte](4096)
  result.write(packet)

proc newDatagramTransport*(): DatagramTransport =
  proc onReceive(
      udp: DatagramTransport, remote: TransportAddress
  ) {.async: (raises: []).} =
    discard

  newDatagramTransport(onReceive)

proc sendTo*(datagram: seq[byte], remote: TransportAddress) {.async.} =
  trace "Sending datagram", remote
  let udp = newDatagramTransport()
  await udp.sendTo(remote, datagram.toUnsafePtr, datagram.len)
  trace "Sent datagram", remote
  await udp.closeWait()
