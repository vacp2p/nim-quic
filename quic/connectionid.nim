import strutils

type ConnectionId* = distinct seq[byte]

proc `==`*(x: ConnectionId, y: ConnectionId): bool {.borrow.}
proc `len`*(x: ConnectionId): int {.borrow.}

proc `$`*(id: ConnectionId): string =
  "0x" & cast[string](id).toHex

const DefaultConnectionIdLength* = 16
