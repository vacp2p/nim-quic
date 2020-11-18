import ngtcp2
import aead
import pointers

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
