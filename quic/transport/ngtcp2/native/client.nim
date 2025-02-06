import pkg/ngtcp2
import pkg/nimcrypto
import ../../version
import ../../../basics
import ../../../helpers/openarray
import ../../connectionid
import ./ids
import ./encryption
import ./keys
import ./settings
import ./cryptodata
import ./connection
import ./path
import ./rand
import ./streams
import ./timestamp
import ./handshake

proc newNgtcp2Client*(local, remote: TransportAddress): Ngtcp2Connection =
  var callbacks: ngtcp2_callbacks
  callbacks.client_initial = ngtcp2_crypto_client_initial_cb
  callbacks.recv_crypto_data = ngtcp2_crypto_recv_crypto_data_cb
  callbacks.recv_retry = ngtcp2_crypto_recv_retry_cb
  callbacks.delete_crypto_aead_ctx = ngtcp2_crypto_delete_crypto_aead_ctx_cb
  callbacks.delete_crypto_cipher_ctx = ngtcp2_crypto_delete_crypto_cipher_ctx_cb
  callbacks.get_path_challenge_data = ngtcp2_crypto_get_path_challenge_data_cb
  callbacks.version_negotiation = ngtcp2_crypto_version_negotiation_cb
  callbacks.rand = rand

  installConnectionIdCallback(callbacks)
  installEncryptionCallbacks(callbacks)
  installClientHandshakeCallback(callbacks)
  installStreamCallbacks(callbacks)

  var settings = defaultSettings()
  var transportParams = defaultTransportParameters()
  settings.initial_ts = now()
  let source = randomConnectionId().toCid
  let destination = randomConnectionId().toCid
  let path = newPath(local, remote)

  result = newConnection(path)
  var conn: ptr ngtcp2_conn

  doAssert 0 == ngtcp2_conn_client_new_versioned(
    addr conn,
    unsafeAddr destination,
    unsafeAddr source,
    path.toPathPtr,
    CurrentQuicVersion,
    NGTCP2_CALLBACKS_V1,
    addr callbacks,
    NGTCP2_SETTINGS_V2,
    unsafeAddr settings,
    NGTCP2_TRANSPORT_PARAMS_V1,
    unsafeAddr transportParams,
    nil,
    addr result[]
  )

  result.conn = Opt.some(conn)
