import std/monotimes
import ngtcp2
import ids
import encrypt
import decrypt
import aead
import hp
import log

var cryptoData: array[4096, uint8]
var retryAead: ngtcp2_crypto_aead
var aeadContext: ngtcp2_crypto_aead_ctx
var hpContext: ngtcp2_crypto_cipher_ctx
var iv: array[16, uint8]

proc clientInitial(connection: ptr ngtcp2_conn, user_data: pointer): cint {.cdecl.} =
  echo "CLIENT: CLIENT INITIAL"
  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection, NGTCP2_CRYPTO_LEVEL_INITIAL, addr cryptoData[0], sizeof(cryptoData).uint
  )

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  echo "CLIENT: RECEIVE CRYPTO DATA"
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

proc clientDefaultSettings: ngtcp2_settings =
  result.initial_rtt = NGTCP2_DEFAULT_INITIAL_RTT
  result.transport_params.initial_max_stream_data_bidi_local = 65535
  result.transport_params.initial_max_stream_data_bidi_remote = 65535
  result.transport_params.initial_max_stream_data_uni = 65535
  result.transport_params.initial_max_data = 128 * 1024
  result.transport_params.initial_max_streams_bidi = 0
  result.transport_params.initial_max_streams_uni = 2
  result.transport_params.max_idle_timeout = 60
  result.transport_params.max_udp_payload_size = 65535
  result.transport_params.stateless_reset_token_present = 0
  result.transport_params.active_connection_id_limit = 8

  result.initial_ts = getMonoTime().ticks.uint
  # result.log_printf = log_printf

proc setupClient*(path: ptr ngtcp2_path, sourceId: ptr ngtcp2_cid, destinationId: ptr ngtcp2_cid): ptr ngtcp2_conn =
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

  ngtcp2_conn_set_retry_aead(result, addr retryAead, addr aeadContext)

  ngtcp2_conn_set_aead_overhead(result, NGTCP2_FAKE_AEAD_OVERHEAD)

