import ngtcp2
import nativesockets

var zeroAddress: Sockaddr
zeroAddress.sa_family = AF_INET.uint16

let zeroPath* = ngtcp2_path(
  local: ngtcp2_addr(`addr`: addr zeroAddress, addrlen: sizeof(SockAddr).uint),
  remote: ngtcp2_addr(`addr`: addr zeroAddress, addrlen: sizeof(SockAddr).uint)
)
