import pkg/chronos
import pkg/ngtcp2
import pkg/questionable
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
  connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_INITIAL)

proc onReceiveCryptoData(connection: ptr ngtcp2_conn,
                        level: ngtcp2_crypto_level,
                        offset: uint64,
                        data: ptr uint8,
                        datalen: uint,
                        userData: pointer): cint {.cdecl.} =
  if level == NGTCP2_CRYPTO_LEVEL_INITIAL:
    connection.installHandshakeKeys()
  if level == NGTCP2_CRYPTO_LEVEL_HANDSHAKE:
    connection.handleCryptoData(toOpenArray(data, datalen))
    connection.install1RttKeys()
    connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_HANDSHAKE)
    ngtcp2_conn_handshake_completed(connection)

proc newNgtcp2Client*(local, remote: TransportAddress): Ngtcp2Connection =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.client_initial = onClientInitial
  callbacks.recv_crypto_data = onReceiveCryptoData
  installConnectionIdCallback(callbacks)
  installEncryptionCallbacks(callbacks)
  installClientHandshakeCallback(callbacks)
  installStreamCallbacks(callbacks)

  var settings = defaultSettings()
  settings.initial_ts = now()
  let source = randomConnectionId().toCid
  let destination = randomConnectionId().toCid
  let path = newPath(local, remote)

  result = newConnection(path)
  var conn: ptr ngtcp2_conn

  doAssert 0 == ngtcp2_conn_client_new(
    addr conn,
    unsafeAddr destination,
    unsafeAddr source,
    path.toPathPtr,
    cast[uint32](NGTCP2_PROTO_VER_MAX),
    addr callbacks,
    unsafeAddr settings,
    nil,
    addr result[]
  )

  result.conn = conn.some
