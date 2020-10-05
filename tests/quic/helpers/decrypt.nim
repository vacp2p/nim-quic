import ngtcp2
import aead

proc dummyDecrypt*(dest: ptr uint8,
                   aead: ptr ngtcp2_crypto_aead,
                   aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                   ciphertext: ptr uint8,
                   ciphertextlen: uint,
                   nonce: ptr uint8,
                   noncelen: uint,
                   ad: ptr uint8,
                   adlen: uint): cint {.cdecl.} =
  assert ciphertextlen >= NGTCP2_FAKE_AEAD_OVERHEAD
  moveMem(dest, ciphertext, ciphertextlen - NGTCP2_FAKE_AEAD_OVERHEAD)

