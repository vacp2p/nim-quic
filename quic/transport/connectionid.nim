import std/strutils
import std/hashes
import bearssl/rand

type ConnectionId* = seq[byte]

const DefaultConnectionIdLength* = 16

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

proc randomConnectionId*(
    rng: ref HmacDrbgContext, len = DefaultConnectionIdLength
): ConnectionId =
  var bytes = newSeq[byte](len)
  if rng.isNil:
    raiseAssert "no rng setup"
  hmacDrbgGenerate(rng[], bytes)
  ConnectionId(bytes)
