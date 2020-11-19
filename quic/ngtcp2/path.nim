import std/nativesockets
import pkg/chronos
import pkg/ngtcp2

type Path* = ref object
  storage: ngtcp2_path_storage

proc toPathPtr*(path: Path): ptr ngtcp2_path =
  addr path.storage.path

proc newPath*(local, remote: TransportAddress): Path =
  var localAddress, remoteAddress: Sockaddr_storage
  var localLength, remoteLength: SockLen
  local.toSAddr(localAddress, localLength)
  remote.toSAddr(remoteAddress, remoteLength)
  new(result)
  ngtcp2_path_storage_init(
    addr result.storage,
    cast[ptr SockAddr](addr localAddress),
    localLength,
    nil,
    cast[ptr SockAddr](addr remoteAddress),
    remoteLength,
    nil
  )

