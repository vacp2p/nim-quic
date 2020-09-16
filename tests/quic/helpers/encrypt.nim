import ngtcp2
import aead

proc dummyEncrypt*(dest: ptr uint8,
                   aead: ptr ngtcp2_crypto_aead,
                   aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                   plaintext: ptr uint8,
                   plaintextlen: uint,
                   nonce: ptr uint8,
                   noncelen: uint,
                   ad: ptr uint8,
                   adlen: uint): cint{.cdecl.} =
  echo "ENCRYPT"
  if plaintextlen.bool and plaintext != dest:
    copyMem(dest, plaintext, plaintextlen)
  zeroMem(cast[ptr uint8](cast[ByteAddress](dest) + ByteAddress(plaintextlen)), NGTCP2_FAKE_AEAD_OVERHEAD)
