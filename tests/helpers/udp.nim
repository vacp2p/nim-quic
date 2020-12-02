import pkg/chronos
import pkg/quic/openarray

proc sendTo*(datagram: seq[byte], remote: TransportAddress) {.async.} =
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    discard
  let udp = newDatagramTransport(onReceive)
  await udp.sendTo(remote, datagram.toUnsafePtr, datagram.len)
  await udp.closeWait()
