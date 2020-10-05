import ngtcp2

type Key* = object
    aeadContext*: ngtcp2_crypto_aead_ctx
    hpContext*: ngtcp2_crypto_cipher_ctx
    iv*: array[16, uint8]
    secret*: array[16, uint8]
