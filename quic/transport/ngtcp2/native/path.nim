import std/nativesockets
import pkg/ngtcp2
import ../../../basics

type Path* = ref object
  storage: ngtcp2_path_storage

proc toPathPtr*(path: Path): ptr ngtcp2_path =
  addr path.storage.path

proc newPath*(local, remote: TransportAddress): Path =
  var localAddress, remoteAddress: Sockaddr_storage
  var localLength, remoteLength: SockLen
  local.toSAddr(localAddress, localLength)
  remote.toSAddr(remoteAddress, remoteLength)
  var path = Path()
  ngtcp2_path_storage_init(
    addr path.storage,
    cast[ptr SockAddr](addr localAddress),
    localLength,
    cast[ptr SockAddr](addr remoteAddress),
    remoteLength,
    nil
  )
  path

