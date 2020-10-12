import ngtcp2

type
  Key* = object
    aeadContext*: ngtcp2_crypto_aead_ctx
    hpContext*: ngtcp2_crypto_cipher_ctx
    iv*: array[16, uint8]
    secret*: array[16, uint8]

proc install0RttKey*(connection: ptr ngtcp2_conn, key: Key) =
  var key = key
  doAssert 0 == connection.ngtcp2_conn_install_initial_key(
    addr key.aeadContext,
    addr key.iv[0],
    addr key.hpContext,
    addr key.aeadContext,
    addr key.iv[0],
    addr key.hpContext,
    key.iv.len.uint
  )

proc installHandshakeKeys*(connection: ptr ngtcp2_conn, rx, tx: Key) =
  var rx = rx
  doAssert 0 == ngtcp2_conn_install_rx_handshake_key(
    connection,
    addr rx.aeadContext,
    addr rx.iv[0],
    rx.iv.len.uint,
    addr rx.hpContext
  )
  var tx = tx
  doAssert 0 == ngtcp2_conn_install_tx_handshake_key(
    connection,
    addr tx.aeadContext,
    addr tx.iv[0],
    tx.iv.len.uint,
    addr tx.hpContext
  )

proc install1RttKeys*(connection: ptr ngtcp2_conn, rx, tx: Key) =
  var rx = rx
  doAssert 0 == ngtcp2_conn_install_rx_key(
    connection,
    addr rx.secret[0],
    rx.secret.len.uint,
    addr rx.aeadContext,
    addr rx.iv[0],
    rx.iv.len.uint,
    addr rx.hpContext
  )
  var tx = tx
  doAssert 0 == ngtcp2_conn_install_tx_key(
    connection,
    addr tx.secret[0],
    tx.secret.len.uint,
    addr tx.aeadContext,
    addr tx.iv[0],
    tx.iv.len.uint,
    addr tx.hpContext
  )
