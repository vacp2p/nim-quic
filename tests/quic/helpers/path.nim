import ngtcp2

proc dummyPath*: ngtcp2_path_storage =
  var local, remote: SocketAddress
  local.ipv4.sin_family = AF_INET
  remote.ipv4.sin_family = AF_INET
  ngtcp2_path_storage_init(
    addr result,
    addr local.address,
    sizeof(local).uint,
    nil,
    addr remote.address,
    sizeof(remote).uint,
    nil
  )
