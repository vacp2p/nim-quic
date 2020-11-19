import chronos
import ngtcp2
import ../connectionid
import ../openarray
import ids
import encryption
import keys
import settings
import cryptodata
import connection
import path
import streams
import timestamp


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

proc onHandshakeCompleted(connection: ptr ngtcp2_conn,
                          userData: pointer): cint {.cdecl.} =
  cast[Connection](userData).handshake.fire()

proc newClientConnection*(local, remote: TransportAddress): Connection =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.client_initial = onClientInitial
  callbacks.recv_crypto_data = onReceiveCryptoData
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.recv_crypto_data = onReceiveCryptoData
  callbacks.handshake_completed = onHandshakeCompleted
  callbacks.stream_open = onStreamOpen
  callbacks.recv_stream_data = onReceiveStreamData
  installEncryptionCallbacks(callbacks)

  var settings = defaultSettings()
  settings.initial_ts = now()
  let source = randomConnectionId().toCid
  let destination = randomConnectionId().toCid
  let path = newPath(local, remote)

  result = newConnection(path)

  doAssert 0 == ngtcp2_conn_client_new(
    addr result.conn,
    unsafeAddr destination,
    unsafeAddr source,
    path.toPathPtr,
    cast[uint32](NGTCP2_PROTO_VER_MAX),
    addr callbacks,
    unsafeAddr settings,
    nil,
    addr result[]
  )
