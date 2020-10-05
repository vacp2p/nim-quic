import ngtcp2
import ids
import encrypt
import decrypt
import aead
import hp
import keys
import settings

var cryptoData: array[4096, uint8]

var randomId: ngtcp2_cid

proc clientInitial(connection: ptr ngtcp2_conn, user_data: pointer): cint {.cdecl.} =
  var initialKey: Key
  assert 0 == ngtcp2_conn_install_initial_key(
    connection,
    addr initialKey.aeadContext,
    addr initialKey.iv[0],
    addr initialKey.hpContext,
    addr initialKey.aeadContext,
    addr initialKey.iv[0],
    addr initialKey.hpContext,
    sizeof(initialKey.iv).uint
  )

  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection, NGTCP2_CRYPTO_LEVEL_INITIAL, addr cryptoData[0], sizeof(cryptoData).uint
  )

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  var params = defaultSettings().transport_params
  params.initial_scid = connection.ngtcp2_conn_get_dcid()[]
  params.original_dcid = randomId
  assert 0 == ngtcp2_conn_set_remote_transport_params(connection, addr params)

  var rxHandshakeKey: Key
  assert 0 == ngtcp2_conn_install_rx_handshake_key(
    connection,
    addr rxHandshakeKey.aeadContext,
    addr rxHandshakeKey.iv[0],
    sizeof(rxHandshakeKey.iv).uint,
    addr rxHandshakeKey.hpContext
  )

  var txHandshakeKey: Key
  assert 0 == ngtcp2_conn_install_tx_handshake_key(
    connection,
    addr txHandshakeKey.aeadContext,
    addr txHandshakeKey.iv[0],
    sizeof(txHandshakeKey.iv).uint,
    addr txHandshakeKey.hpContext
  )

  ngtcp2_conn_handshake_completed(connection)

proc receiveClientInitial(connection: ptr ngtcp2_conn, dcid: ptr ngtcp2_cid, userData: pointer): cint {.cdecl.} =
  discard

proc random(dest: ptr uint8, destlen: uint, rand_ctx: ptr ngtcp2_rand_ctx, usage: ngtcp2_rand_usage): cint {.cdecl.} =
  discard

proc updateKey(conn: ptr ngtcp2_conn, rx_secret: ptr uint8, tx_secret: ptr uint8, rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, rx_iv: ptr uint8, tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, tx_iv: ptr uint8, current_rx_secret: ptr uint8, current_tx_secret: ptr uint8, secretlen: uint, user_data: pointer): cint {.cdecl} =
  discard

proc handshakeConfirmed(conn: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  discard

proc handshakeCompleted(connection: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  var rxKey: Key
  assert 0 == ngtcp2_conn_install_rx_key(
    connection,
    addr rxKey.secret[0],
    rxKey.secret.len.uint,
    addr rxKey.aeadContext,
    addr rxKey.iv[0],
    rxKey.iv.len.uint,
    addr rxKey.hpContext
  )

  var txKey: Key
  assert 0 == ngtcp2_conn_install_tx_key(
    connection,
    addr txKey.secret[0],
    txKey.secret.len.uint,
    addr txKey.aeadContext,
    addr txKey.iv[0],
    txKey.iv.len.uint,
    addr txKey.hpContext
  )

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

  var settings = defaultSettings()

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

  ngtcp2_conn_set_aead_overhead(result, NGTCP2_FAKE_AEAD_OVERHEAD)

