import ngtcp2
import bearssl/rand

proc onRand*(
    dest: ptr uint8, destLen: csize_t, rand_ctx: ptr ngtcp2_rand_ctx
) {.cdecl.} =
  if rand_ctx.native_handle.isNil:
    raiseAssert "no rng setup"
  var rng = cast[ref HmacDrbgContext](rand_ctx.native_handle)
  hmacDrbgGenerate(rng[], cast[pointer](dest), uint(destLen))
