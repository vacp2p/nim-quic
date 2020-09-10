import ngtcp2
import encrypt
import decrypt
import hp
import ids
import path

var cryptoData: array[4096, uint8]
var aeadContext: ngtcp2_crypto_aead_ctx
var hpContext: ngtcp2_crypto_cipher_ctx
var iv: array[16, uint8]
var nullpath = dummyPath()

proc receiveClientInitial(connection: ptr ngtcp2_conn, dcid: ptr ngtcp2_cid, userData: pointer): cint {.cdecl.} =
  assert 0 == ngtcp2_conn_install_early_key(connection, addr aeadContext, addr iv[0], sizeof(iv).uint, addr hpContext)

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection,
    if level == NGTCP2_CRYPTO_LEVEL_INITIAL: NGTCP2_CRYPTO_LEVEL_INITIAL else: NGTCP2_CRYPTO_LEVEL_HANDSHAKE,
    addr cryptoData[0],
    218
  )

proc serverDefaultSettings: ngtcp2_settings =
  result.initial_rtt = NGTCP2_DEFAULT_INITIAL_RTT
  result.transport_params.initial_max_stream_data_bidi_local = 65535
  result.transport_params.initial_max_stream_data_bidi_remote = 65535
  result.transport_params.initial_max_stream_data_uni = 65535
  result.transport_params.initial_max_data = 128 * 1024
  result.transport_params.initial_max_streams_bidi = 3
  result.transport_params.initial_max_streams_uni = 2
  result.transport_params.max_idle_timeout = 60
  result.transport_params.max_udp_payload_size = 65535
  result.transport_params.stateless_reset_token_present = 1
  result.transport_params.active_connection_id_limit = 8
  for i in 0..<NGTCP2_STATELESS_RESET_TOKENLEN:
    result.transport_params.stateless_reset_token[i] = uint8(i)

proc setupServer*: ptr ngtcp2_conn =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.recv_client_initial = receiveClientInitial
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.decrypt = dummyDecrypt
  callbacks.encrypt = dummyEncrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.get_new_connection_id = getNewConnectionId

  var settings = serverDefaultSettings()

  assert 0 == ngtcp2_conn_client_new(
    addr result,
    addr destinationId,
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

  ngtcp2_conn_set_aead_overhead(result, 0)
