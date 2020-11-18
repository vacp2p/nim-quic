import ngtcp2
import pointers

const aeadlen* = 16

proc dummyEncrypt*(dest: ptr uint8,
                   aead: ptr ngtcp2_crypto_aead,
                   aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                   plaintext: ptr uint8,
                   plaintextlen: uint,
                   nonce: ptr uint8,
                   noncelen: uint,
                   ad: ptr uint8,
                   adlen: uint): cint{.cdecl.} =
  moveMem(dest, plaintext, plaintextlen)
  zeroMem(dest + plaintextlen.int, aeadlen)

proc dummyDecrypt*(dest: ptr uint8,
                   aead: ptr ngtcp2_crypto_aead,
                   aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                   ciphertext: ptr uint8,
                   ciphertextlen: uint,
                   nonce: ptr uint8,
                   noncelen: uint,
                   ad: ptr uint8,
                   adlen: uint): cint {.cdecl.} =
  moveMem(dest, ciphertext, ciphertextlen - aeadlen)

proc dummyHpMask*(dest: ptr uint8,
                  hp: ptr ngtcp2_crypto_cipher,
                  hpContext: ptr ngtcp2_crypto_cipher_ctx,
                  sample: ptr uint8): cint {.cdecl.} =
  var NGTCP2_FAKE_HP_MASK = "\x00\x00\x00\x00\x00"
  copyMem(dest, addr NGTCP2_FAKE_HP_MASK[0], NGTCP2_FAKE_HP_MASK.len)
