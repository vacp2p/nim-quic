import ngtcp2
import ids
import encrypt
import decrypt
import aead
import hp
import settings

type
  InitialKey = object
    aeadContext: ngtcp2_crypto_aead_ctx
    iv: array[16, uint8]
    hpContext: ngtcp2_crypto_cipher_ctx
  HandshakeKey = object
    aeadContext: ngtcp2_crypto_aead_ctx
    iv: array[16, uint8]
    hpContext: ngtcp2_crypto_cipher_ctx
  TxKey = object
    aeadContext: ngtcp2_crypto_aead_ctx
    iv: array[16, uint8]
    hpContext: ngtcp2_crypto_cipher_ctx
    secret: array[16, uint8]
  RxKey = object
    aeadContext: ngtcp2_crypto_aead_ctx
    iv: array[16, uint8]
    hpContext: ngtcp2_crypto_cipher_ctx
    secret: array[16, uint8]
  RetryAead = object
    aeadContext: ngtcp2_crypto_aead_ctx
    aead : ngtcp2_crypto_aead

var cryptoData: array[4096, uint8]

var randomId: ngtcp2_cid

proc clientInitial(connection: ptr ngtcp2_conn, user_data: pointer): cint {.cdecl.} =
  echo "CLIENT: CLIENT INITIAL"
  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection, NGTCP2_CRYPTO_LEVEL_INITIAL, addr cryptoData[0], sizeof(cryptoData).uint
  )

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  echo "CLIENT: RECEIVE CRYPTO DATA"

  var params = serverDefaultSettings().transport_params
  params.initial_scid = connection.ngtcp2_conn_get_dcid()[]
  params.original_dcid = randomId
  assert 0 == ngtcp2_conn_set_remote_transport_params(connection, addr params)

  var rxKey: RxKey
  assert 0 == ngtcp2_conn_install_rx_key(
    connection,
    addr rxKey.secret[0],
    rxKey.secret.len.uint,
    addr rxKey.aeadContext,
    addr rxKey.iv[0],
    rxKey.iv.len.uint,
    addr rxKey.hpContext
  )

  var txKey: TxKey
  assert 0 == ngtcp2_conn_install_tx_key(
    connection,
    addr txKey.secret[0],
    txKey.secret.len.uint,
    addr txKey.aeadContext,
    addr txKey.iv[0],
    txKey.iv.len.uint,
    addr txKey.hpContext
  )

  ngtcp2_conn_handshake_completed(connection)

proc receiveClientInitial(connection: ptr ngtcp2_conn, dcid: ptr ngtcp2_cid, userData: pointer): cint {.cdecl.} =
  echo "CLIENT: RECEIVE CLIENT INITIAL"

proc random(dest: ptr uint8, destlen: uint, rand_ctx: ptr ngtcp2_rand_ctx, usage: ngtcp2_rand_usage): cint {.cdecl.} =
  echo "CLIENT: RANDOM"

proc updateKey(conn: ptr ngtcp2_conn, rx_secret: ptr uint8, tx_secret: ptr uint8, rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, rx_iv: ptr uint8, tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, tx_iv: ptr uint8, current_rx_secret: ptr uint8, current_tx_secret: ptr uint8, secretlen: uint, user_data: pointer): cint {.cdecl} =
  echo "CLIENT: UPDATE KEY"

proc handshakeConfirmed(conn: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  echo "CLIENT: HANDSHAKE CONFIRMED"

proc handshakeCompleted(conn: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  echo "CLIENT: HANDSHAKE COMPLETED"

proc setupClient*(path: ptr ngtcp2_path, sourceId: ptr ngtcp2_cid, destinationId: ptr ngtcp2_cid): ptr ngtcp2_conn =
  randomId = destinationId[]

  var callbacks: ngtcp2_conn_callbacks
  callbacks.client_initial = clientInitial
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.decrypt = dummyDecrypt
  callbacks.encrypt = dummyEncrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.recv_client_initial = receiveClientInitial
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.rand = random
  callbacks.update_key = updateKey
  callbacks.handshake_completed = handshakeCompleted
  callbacks.handshake_confirmed = handshakeConfirmed

  var settings = clientDefaultSettings()

  assert 0 == ngtcp2_conn_client_new(
    addr result,
    destinationId,
    sourceId,
    path,
    cast[uint32](NGTCP2_PROTO_VER),
    addr callbacks,
    addr settings,
    nil,
    nil
  )

  var initialKey: InitialKey
  assert 0 == ngtcp2_conn_install_initial_key(
    result,
    addr initialKey.aeadContext,
    addr initialKey.iv[0],
    addr initialKey.hpContext,
    addr initialKey.aeadContext,
    addr initialKey.iv[0],
    addr initialKey.hpContext,
    sizeof(initialKey.iv).uint
  )

  var rxHandshakeKey: HandshakeKey
  assert 0 == ngtcp2_conn_install_rx_handshake_key(
    result,
    addr rxHandshakeKey.aeadContext,
    addr rxHandshakeKey.iv[0],
    sizeof(rxHandshakeKey.iv).uint,
    addr rxHandshakeKey.hpContext
  )

  var txHandshakeKey: HandshakeKey
  assert 0 == ngtcp2_conn_install_tx_handshake_key(
    result,
    addr txHandshakeKey.aeadContext,
    addr txHandshakeKey.iv[0],
    sizeof(txHandshakeKey.iv).uint,
    addr txHandshakeKey.hpContext
  )


  var retryAead: RetryAead
  ngtcp2_conn_set_retry_aead(result, addr retryAead.aead, addr retryAead.aeadContext)

  ngtcp2_conn_set_aead_overhead(result, NGTCP2_FAKE_AEAD_OVERHEAD)

