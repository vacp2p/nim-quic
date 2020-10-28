import std/strutils

proc contains*(a: seq[byte], sub: seq[byte]): bool =
  cast[string](a).contains(cast[string](sub))
