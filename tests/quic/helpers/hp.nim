import ngtcp2

proc dummyHpMask*(dest: ptr uint8, hp: ptr ngtcp2_crypto_cipher, hpContext: ptr ngtcp2_crypto_cipher_ctx, sample: ptr uint8): cint {.cdecl.} =
  var NGTCP2_FAKE_HP_MASK = "\x00\x00\x00\x00\x00"
  copyMem(dest, addr NGTCP2_FAKE_HP_MASK[0], NGTCP2_FAKE_HP_MASK.len)

