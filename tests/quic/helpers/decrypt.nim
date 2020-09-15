import ngtcp2

proc dummyDecrypt*(dest: ptr uint8,
                   aead: ptr ngtcp2_crypto_aead,
                   aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                   ciphertext: ptr uint8,
                   ciphertextlen: uint,
                   nonce: ptr uint8,
                   noncelen: uint,
                   ad: ptr uint8,
                   adlen: uint): cint {.cdecl.} =
  echo "DECRYPT"
  copyMem(dest, ciphertext, ciphertextlen)

