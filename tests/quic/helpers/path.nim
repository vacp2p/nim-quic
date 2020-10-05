import ngtcp2

var zeroAddress: SocketAddress
zeroAddress.ipv4.sin_family = AF_INET

var zeroPath* = ngtcp2_path(
  local: ngtcp2_addr(`addr`: addr zeroAddress.address, addrlen: sizeof(SocketAddress).uint),
  remote: ngtcp2_addr(`addr`: addr zeroAddress.address, addrlen: sizeof(SocketAddress).uint)
)
