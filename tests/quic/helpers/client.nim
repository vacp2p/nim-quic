import ngtcp2
import ids
import encrypt
import decrypt
import hp
import path

var cryptoData: array[4096, uint8]
var retryAead: ngtcp2_crypto_aead
var aeadContext: ngtcp2_crypto_aead_ctx
var hpContext: ngtcp2_crypto_cipher_ctx
var iv: array[16, uint8]
var nullpath = dummyPath()

proc clientInitial(connection: ptr ngtcp2_conn, user_data: pointer): cint {.cdecl.} =
  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection, NGTCP2_CRYPTO_LEVEL_INITIAL, addr cryptoData[0], 217
  )

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  discard

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

proc setupClient*: ptr ngtcp2_conn =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.client_initial = clientInitial
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.decrypt = dummyDecrypt
  callbacks.encrypt = dummyEncrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.get_new_connection_id = getNewConnectionId

  var settings = clientDefaultSettings()

  assert 0 == ngtcp2_conn_client_new(
    addr result,
    addr randomId,
    addr sourceId,
    addr nullpath.path,
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
