import ngtcp2
import nimcrypto

proc onRand*(
    dest: ptr uint8, destLen: csize_t, rand_ctx: ptr ngtcp2_rand_ctx
) {.cdecl.} =
  # TODO: external source of randomness?
  doAssert destLen.int == randomBytes(dest, destLen.int)
