import std/strutils
import bearssl/rand
import ../helpers/sequninit

type ConnectionId* = seq[byte]

const DefaultConnectionIdLength* = 16

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

proc randomConnectionId*(
    rng: ref HmacDrbgContext, len = DefaultConnectionIdLength
): ConnectionId =
  if rng.isNil:
    raiseAssert "no rng setup"

  var bytes = newSeqUninit[byte](len)
  hmacDrbgGenerate(rng[], bytes)
  ConnectionId(bytes)
