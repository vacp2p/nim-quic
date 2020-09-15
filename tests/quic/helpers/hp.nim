import ngtcp2

proc dummyHpMask*(dest: ptr uint8, hp: ptr ngtcp2_crypto_cipher, hpContext: ptr ngtcp2_crypto_cipher_ctx, sample: ptr uint8): cint {.cdecl.} =
  # memcpy(dest, NGTCP2_FAKE_HP_MASK, sizeof(NGTCP2_FAKE_HP_MASK) - 1);
  echo "HP MASK"

