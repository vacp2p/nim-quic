import pkg/ngtcp2
import ./pointers

const aeadlen* = 16

proc dummyEncrypt(dest: ptr uint8,
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

proc dummyDecrypt(dest: ptr uint8,
                   aead: ptr ngtcp2_crypto_aead,
                   aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                   ciphertext: ptr uint8,
                   ciphertextlen: uint,
                   nonce: ptr uint8,
                   noncelen: uint,
                   ad: ptr uint8,
                   adlen: uint): cint {.cdecl.} =
  moveMem(dest, ciphertext, ciphertextlen - aeadlen)

proc dummyHpMask(dest: ptr uint8,
                  hp: ptr ngtcp2_crypto_cipher,
                  hpContext: ptr ngtcp2_crypto_cipher_ctx,
                  sample: ptr uint8): cint {.cdecl.} =
  var NGTCP2_FAKE_HP_MASK = "\x00\x00\x00\x00\x00"
  copyMem(dest, addr NGTCP2_FAKE_HP_MASK[0], NGTCP2_FAKE_HP_MASK.len)

proc dummyUpdateKey(conn: ptr ngtcp2_conn,
                     rx_secret, : ptr uint8,
                     tx_secret: ptr uint8,
                     rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                     rx_iv: ptr uint8,
                     tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                     tx_iv: ptr uint8,
                     current_rx_secret: ptr uint8,
                     current_tx_secret: ptr uint8,
                     secretlen: uint,
                     user_data: pointer): cint {.cdecl.} =
  discard

proc installEncryptionCallbacks*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.encrypt = dummyEncrypt
  callbacks.decrypt = dummyDecrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.update_key = dummyUpdateKey
