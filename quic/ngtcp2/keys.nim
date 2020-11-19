import pkg/ngtcp2
import ../openarray
import ./encryption

type
  Secret = seq[byte]
  AuthenticatedEncryptionWithAssociatedData = object
    context: ngtcp2_crypto_aead_ctx
  HeaderProtection = object
    context: ngtcp2_crypto_cipher_ctx
  Key = object
    aead: AuthenticatedEncryptionWithAssociatedData
    hp: HeaderProtection
    iv: seq[byte]
  CryptoContext = ngtcp2_crypto_ctx

proc dummyCryptoContext: CryptoContext =
  result.max_encryption = 1000

proc dummyKey: Key =
  result.iv = cast[seq[byte]]("dummykey")

proc dummySecret: Secret =
  cast[seq[byte]]("dummysecret")

proc install0RttKey*(connection: ptr ngtcp2_conn) =
  let context = dummyCryptoContext()
  connection.ngtcp2_conn_set_initial_crypto_ctx(unsafeAddr context)
  let key = dummyKey()
  doAssert 0 == connection.ngtcp2_conn_install_initial_key(
    key.aead.context.unsafeAddr,
    key.iv.toUnsafePtr,
    key.hp.context.unsafeAddr,
    key.aead.context.unsafeAddr,
    key.iv.toUnsafePtr,
    key.hp.context.unsafeAddr,
    key.iv.len.uint
  )

proc installHandshakeKeys*(connection: ptr ngtcp2_conn) =
  let context = dummyCryptoContext()
  connection.ngtcp2_conn_set_crypto_ctx(unsafeAddr context)
  let rx, tx = dummyKey()
  doAssert 0 == ngtcp2_conn_install_rx_handshake_key(
    connection,
    rx.aead.context.unsafeAddr,
    rx.iv.toUnsafePtr,
    rx.iv.len.uint,
    rx.hp.context.unsafeAddr
  )
  doAssert 0 == ngtcp2_conn_install_tx_handshake_key(
    connection,
    tx.aead.context.unsafeAddr,
    tx.iv.toUnsafePtr,
    tx.iv.len.uint,
    tx.hp.context.unsafeAddr
  )

proc install1RttKeys*(connection: ptr ngtcp2_conn) =
  ngtcp2_conn_set_aead_overhead(connection, aeadlen)
  let secret = dummySecret()
  let rx, tx = dummyKey()
  doAssert 0 == ngtcp2_conn_install_rx_key(
    connection,
    secret.toUnsafePtr,
    secret.len.uint,
    rx.aead.context.unsafeAddr,
    rx.iv.toUnsafePtr,
    rx.iv.len.uint,
    rx.hp.context.unsafeAddr
  )
  doAssert 0 == ngtcp2_conn_install_tx_key(
    connection,
    secret.toUnsafePtr,
    secret.len.uint,
    tx.aead.context.unsafeAddr,
    tx.iv.toUnsafePtr,
    tx.iv.len.uint,
    tx.hp.context.unsafeAddr
  )
