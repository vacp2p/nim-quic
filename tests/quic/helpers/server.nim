import ngtcp2
import encrypt
import decrypt
import aead
import hp
import ids
import keys
import settings

let zeroKey = Key()
var cryptoData: array[4096, uint8]

proc receiveClientInitial(connection: ptr ngtcp2_conn, dcid: ptr ngtcp2_cid, userData: pointer): cint {.cdecl.} =
  connection.install0RttKey(zeroKey)
  connection.installHandshakeKeys(zeroKey, zeroKey)

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection,
    if level == NGTCP2_CRYPTO_LEVEL_INITIAL: NGTCP2_CRYPTO_LEVEL_INITIAL else: NGTCP2_CRYPTO_LEVEL_HANDSHAKE,
    addr cryptoData[0],
    sizeof(cryptoData).uint
  )

  var params = defaultSettings().transport_params
  params.initial_scid = connection.ngtcp2_conn_get_dcid()[]
  assert 0 == ngtcp2_conn_set_remote_transport_params(connection, addr params)

  ngtcp2_conn_handshake_completed(connection)

proc updateKey(conn: ptr ngtcp2_conn, rx_secret: ptr uint8, tx_secret: ptr uint8, rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, rx_iv: ptr uint8, tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, tx_iv: ptr uint8, current_rx_secret: ptr uint8, current_tx_secret: ptr uint8, secretlen: uint, user_data: pointer): cint {.cdecl} =
  discard

proc handshakeCompleted(connection: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  connection.install1RttKeys(zeroKey, zeroKey)

proc setupServer*(path: ptr ngtcp2_path, sourceId: ptr ngtcp2_cid, destinationId: ptr ngtcp2_cid): ptr ngtcp2_conn =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.recv_client_initial = receiveClientInitial
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.decrypt = dummyDecrypt
  callbacks.encrypt = dummyEncrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.update_key = updateKey
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

  ngtcp2_conn_set_aead_overhead(result, NGTCP2_FAKE_AEAD_OVERHEAD)
