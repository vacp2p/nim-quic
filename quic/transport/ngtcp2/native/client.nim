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
import ./streams
import ./timestamp
import ./handshake


proc onClientInitial(connection: ptr ngtcp2_conn,
                     user_data: pointer): cint {.cdecl.} =
  connection.install0RttKey()
  connection.submitCryptoData(NGTCP2_ENCRYPTION_LEVEL_INITIAL)

proc onReceiveCryptoData(connection: ptr ngtcp2_conn,
                        level: ngtcp2_encryption_level,
                        offset: uint64,
                        data: ptr uint8,
                        datalen: uint,
                        userData: pointer): cint {.cdecl.} =
  if level == NGTCP2_ENCRYPTION_LEVEL_INITIAL:
    connection.installHandshakeKeys()
  if level == NGTCP2_ENCRYPTION_LEVEL_HANDSHAKE:
    connection.handleCryptoData(toOpenArray(data, datalen))
    connection.install1RttKeys()
    connection.submitCryptoData(NGTCP2_ENCRYPTION_LEVEL_HANDSHAKE)
    ngtcp2_conn_tls_handshake_completed(connection)

proc onReceiveRetry(connection: ptr ngtcp2_conn,
                    hd: ptr ngtcp2_pkt_hd,
                    userData: pointer): cint {.cdecl.} =

  return 0

proc onRand(dest: ptr uint8, destLen: uint, rand_ctx: ptr ngtcp2_rand_ctx) {.cdecl.} =
  doAssert destLen.int == randomBytes(dest, destLen.int)

proc onDeleteCryptoAeadCtx(conn: ptr ngtcp2_conn,
                         aead_ctx: ptr ngtcp2_crypto_aead_ctx,
                         userData: pointer) {.cdecl.} =
  discard

proc onDeleteCryptoCipherCtx(conn: ptr ngtcp2_conn,
                         cipher_ctx: ptr ngtcp2_crypto_cipher_ctx,
                         userData: pointer) {.cdecl.} =
  discard

proc onGetPathChallengeData(conn: ptr ngtcp2_conn,
                          data: ptr uint8,
                          userData: pointer): cint {.cdecl.} =
  let bytesWritten = randomBytes(data, NGTCP2_PATH_CHALLENGE_DATALEN)
  if bytesWritten != NGTCP2_PATH_CHALLENGE_DATALEN:
    return NGTCP2_ERR_CALLBACK_FAILURE
  return 0

proc newNgtcp2Client*(local, remote: TransportAddress): Ngtcp2Connection =
  var callbacks: ngtcp2_callbacks
  callbacks.client_initial = onClientInitial
  callbacks.recv_crypto_data = onReceiveCryptoData
  callbacks.recv_retry = onReceiveRetry
  callbacks.rand = onRand
  callbacks.delete_crypto_aead_ctx = onDeleteCryptoAeadCtx
  callbacks.delete_crypto_cipher_ctx = onDeleteCryptoCipherCtx
  callbacks.get_path_challenge_data = onGetPathChallengeData

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
