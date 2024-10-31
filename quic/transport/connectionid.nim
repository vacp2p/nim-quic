import std/strutils
import std/hashes
import pkg/nimcrypto

type ConnectionId* = seq[byte]

const DefaultConnectionIdLength* = 16

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

proc randomConnectionId*(len = DefaultConnectionIdLength): ConnectionId =
  var bytes = newSeq[byte](len)
  doAssert len == randomBytes(addr bytes[0], len)
  ConnectionId(bytes)
