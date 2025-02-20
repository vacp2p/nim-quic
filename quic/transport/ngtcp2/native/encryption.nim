import ngtcp2

proc installEncryptionCallbacks*(callbacks: var ngtcp2_callbacks) =
  callbacks.encrypt = ngtcp2_crypto_encrypt_cb
  callbacks.decrypt = ngtcp2_crypto_decrypt_cb
  callbacks.hp_mask = ngtcp2_crypto_hp_mask_cb
  callbacks.update_key = ngtcp2_crypto_update_key_cb
