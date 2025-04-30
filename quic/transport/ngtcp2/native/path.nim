import std/nativesockets
import ngtcp2
import ../../../basics

type Path* = ref object
  path: ngtcp2_path
  localAddress: Sockaddr_storage
  localAddrLen: SockLen
  remoteAddress: Sockaddr_storage
  remoteAddrLen: SockLen

proc toPathPtr*(path: Path): ptr ngtcp2_path =
  addr path.path

proc newPath*(local, remote: TransportAddress): Path =
  var p = Path()
  local.toSAddr(p.localAddress, p.localAddrLen)
  remote.toSAddr(p.remoteAddress, p.remoteAddrLen)
  p.path = ngtcp2_path(
    local: ngtcp2_addr(
      addr_field: cast[ptr ngtcp2_sockaddr](p.localAddress.addr),
      addr_len: p.localAddrLen,
    ),
    remote: ngtcp2_addr(
      addr_field: cast[ptr ngtcp2_sockaddr](p.remoteAddress.addr),
      addr_len: p.remoteAddrLen,
    ),
    user_data: nil,
  )
  p
