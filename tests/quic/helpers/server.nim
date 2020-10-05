import ngtcp2
import encrypt
import decrypt
import aead
import hp
import ids
import settings

type
  RxKey = object
    aeadContext: ngtcp2_crypto_aead_ctx
    iv: array[16, uint8]
    hpContext: ngtcp2_crypto_cipher_ctx
    secret: array[16, uint8]
  TxKey = object
    aeadContext: ngtcp2_crypto_aead_ctx
    iv: array[16, uint8]
    hpContext: ngtcp2_crypto_cipher_ctx
    secret: array[16, uint8]

var cryptoData: array[4096, uint8]
var aeadContext: ngtcp2_crypto_aead_ctx
var hpContext: ngtcp2_crypto_cipher_ctx
var iv: array[16, uint8]

proc receiveClientInitial(connection: ptr ngtcp2_conn, dcid: ptr ngtcp2_cid, userData: pointer): cint {.cdecl.} =
  echo "SERVER: RECEIVE CLIENT INITIAL"
  assert 0 == ngtcp2_conn_install_early_key(connection, addr aeadContext, addr iv[0], sizeof(iv).uint, addr hpContext)

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  echo "SERVER: RECEIVE CRYPTO DATA"
  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection,
    if level == NGTCP2_CRYPTO_LEVEL_INITIAL: NGTCP2_CRYPTO_LEVEL_INITIAL else: NGTCP2_CRYPTO_LEVEL_HANDSHAKE,
    addr cryptoData[0],
    sizeof(cryptoData).uint
  )

  var params = defaultSettings().transport_params
  params.initial_scid = connection.ngtcp2_conn_get_dcid()[]
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

proc receiveStreamData(connection: ptr ngtcp2_conn, flags: uint32, stream_id: int64, offset: uint64, data: ptr uint8, datalen: uint, user_data: pointer, stream_user_data: pointer): cint {.cdecl.} =
  echo "SERVER: RECEIVE STREAM DATA"

proc clientInitial(connection: ptr ngtcp2_conn, user_data: pointer): cint {.cdecl.} =
  echo "SERVER: CLIENT INITIAL"

proc random(dest: ptr uint8, destlen: uint, rand_ctx: ptr ngtcp2_rand_ctx, usage: ngtcp2_rand_usage): cint {.cdecl.} =
  echo "SERVER: RANDOM"

proc updateKey(conn: ptr ngtcp2_conn, rx_secret: ptr uint8, tx_secret: ptr uint8, rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, rx_iv: ptr uint8, tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, tx_iv: ptr uint8, current_rx_secret: ptr uint8, current_tx_secret: ptr uint8, secretlen: uint, user_data: pointer): cint {.cdecl} =
  echo "SERVER: UPDATE KEY"

proc handshakeConfirmed(conn: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  echo "SERVER: HANDSHAKE CONFIRMED"

proc handshakeCompleted(conn: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  echo "SERVER: HANDSHAKE COMPLETED"

proc setupServer*(path: ptr ngtcp2_path, sourceId: ptr ngtcp2_cid, destinationId: ptr ngtcp2_cid): ptr ngtcp2_conn =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.recv_client_initial = receiveClientInitial
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.decrypt = dummyDecrypt
  callbacks.encrypt = dummyEncrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.recv_stream_data = receiveStreamData
  callbacks.client_initial = clientInitial
  callbacks.rand = random
  callbacks.update_key = updateKey
  callbacks.handshake_confirmed = handshakeConfirmed
  callbacks.handshake_completed = handshakeCompleted

  var settings = defaultSettings()

  assert 0 == ngtcp2_conn_server_new(
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

  assert 0 == ngtcp2_conn_install_initial_key(
    result,
    addr aeadContext,
    addr iv[0],
    addr hpContext,
    addr aeadContext,
    addr iv[0],
    addr hpContext,
    sizeof(iv).uint
  )

  assert 0 == ngtcp2_conn_install_rx_handshake_key(
    result,
    addr aeadContext,
    addr iv[0],
    sizeof(iv).uint,
    addr hpContext
  )

  assert 0 == ngtcp2_conn_install_tx_handshake_key(
    result,
    addr aeadContext,
    addr iv[0],
    sizeof(iv).uint,
    addr hpContext
  )

  ngtcp2_conn_set_aead_overhead(result, NGTCP2_FAKE_AEAD_OVERHEAD)
