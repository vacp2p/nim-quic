import std/strutils
import std/hashes
import pkg/nimcrypto

type ConnectionId* = distinct seq[byte]

const DefaultConnectionIdLength* = 16

proc `==`*(x: ConnectionId, y: ConnectionId): bool {.borrow.}
proc `len`*(x: ConnectionId): int {.borrow.}
proc `hash`*(x: ConnectionId): Hash {.borrow.}

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

proc randomConnectionId*(len = DefaultConnectionIdLength): ConnectionId =
  var bytes = newSeq[byte](len)
  doAssert len == randomBytes(addr bytes[0], len)
  ConnectionId(bytes)
