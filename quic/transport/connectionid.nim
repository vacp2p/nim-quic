import std/strutils
import std/hashes
import bearssl/rand

type ConnectionId* = distinct seq[byte]

const DefaultConnectionIdLength* = 16

proc `==`*(x: ConnectionId, y: ConnectionId): bool {.borrow.}
proc `len`*(x: ConnectionId): int {.borrow.}
proc `hash`*(x: ConnectionId): Hash {.borrow.}

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
