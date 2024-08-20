import pkg/ngtcp2
import pkg/nimcrypto

import ../../../basics
import ../../../helpers/openarray
import ../../packets
import ../../version
import ./encryption
import ./ids
import ./keys
import ./settings
import ./cryptodata
import ./connection
import ./path
import ./streams
import ./timestamp
import ./handshake
import ./parsedatagram

proc onReceiveClientInitial(connection: ptr ngtcp2_conn,
                            dcid: ptr ngtcp2_cid,
                            userData: pointer): cint {.cdecl.} =
  connection.install0RttKey()

proc onReceiveCryptoData(connection: ptr ngtcp2_conn,
                         level: ngtcp2_encryption_level,
                         offset: uint64,
                         data: ptr uint8,
                         datalen: uint,
                         userData: pointer): cint {.cdecl.} =
  if level == NGTCP2_ENCRYPTION_LEVEL_INITIAL:
    connection.submitCryptoData(NGTCP2_ENCRYPTION_LEVEL_INITIAL)
    connection.installHandshakeKeys()
    connection.handleCryptoData(toOpenArray(data, datalen))
    connection.submitCryptoData(NGTCP2_ENCRYPTION_LEVEL_HANDSHAKE)
    connection.install1RttKeys()
  if level == NGTCP2_ENCRYPTION_LEVEL_HANDSHAKE:
    connection.submitCryptoData(NGTCP2_ENCRYPTION_LEVEL_1RTT)
    ngtcp2_conn_tls_handshake_completed(connection)

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
  doAssert NGTCP2_PATH_CHALLENGE_DATALEN == randomBytes(data, NGTCP2_PATH_CHALLENGE_DATALEN)

proc newNgtcp2Server*(local, remote: TransportAddress,
                     source, destination: ngtcp2_cid): Ngtcp2Connection =
  var callbacks: ngtcp2_callbacks
  callbacks.recv_client_initial = onReceiveClientInitial
  callbacks.recv_crypto_data = onReceiveCryptoData
  callbacks.rand = onRand
  callbacks.delete_crypto_aead_ctx = onDeleteCryptoAeadCtx
  callbacks.delete_crypto_cipher_ctx = onDeleteCryptoCipherCtx
  callbacks.get_path_challenge_data = onGetPathChallengeData

  installConnectionIdCallback(callbacks)
  installEncryptionCallbacks(callbacks)
  installServerHandshakeCallback(callbacks)
  installStreamCallbacks(callbacks)

  var settings = defaultSettings()
  var transportParams = defaultTransportParameters()
  transportParams.original_dcid = destination
  transportParams.original_dcid_present = 1
  settings.initial_ts = now()

  let id = randomConnectionId().toCid
  let path = newPath(local, remote)

  result = newConnection(path)
  var conn: ptr ngtcp2_conn

  doAssert 0 == ngtcp2_conn_server_new_versioned(
    addr conn,
    unsafeAddr source,
    unsafeAddr id,
    path.toPathPtr,
    CurrentQuicVersion,
    NGTCP2_CALLBACKS_V1,
    addr callbacks,
    NGTCP2_SETTINGS_V2,
    addr settings,
    NGTCP2_TRANSPORT_PARAMS_V1,
    unsafeAddr transportParams,
    nil,
    addr result[]
  )

  result.conn = Opt.some(conn)

proc extractIds(datagram: openArray[byte]): tuple[source, dest: ngtcp2_cid] =
  let info = parseDatagram(datagram)
  (source: info.source.toCid, dest: info.destination.toCid)

proc newNgtcp2Server*(local, remote: TransportAddress,
    datagram: openArray[byte]): Ngtcp2Connection =
  let (source, destination) = extractIds(datagram)
  newNgtcp2Server(local, remote, source, destination)
