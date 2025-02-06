import pkg/ngtcp2
import pkg/nimcrypto

proc rand*(dest: ptr uint8, destLen: uint, rand_ctx: ptr ngtcp2_rand_ctx) {.cdecl.} =
  # TODO: external source of randomness?
  doAssert destLen.int == randomBytes(dest, destLen.int)
