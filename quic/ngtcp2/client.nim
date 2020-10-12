import chronos
import ngtcp2
import ../connectionid
import ../openarray
import ids
import encrypt
import decrypt
import hp
import keys
import settings
import crypto
import connection
import path

let zeroKey = Key()

proc clientInitial(connection: ptr ngtcp2_conn, user_data: pointer): cint {.cdecl.} =
  connection.install0RttKey(zeroKey)
  connection.submitCryptoData()

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  connection.handleCryptoData(toOpenArray(data, datalen))
  connection.installHandshakeKeys(zeroKey, zeroKey)
  ngtcp2_conn_handshake_completed(connection)

proc updateKey(conn: ptr ngtcp2_conn, rx_secret: ptr uint8, tx_secret: ptr uint8, rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, rx_iv: ptr uint8, tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, tx_iv: ptr uint8, current_rx_secret: ptr uint8, current_tx_secret: ptr uint8, secretlen: uint, user_data: pointer): cint {.cdecl} =
  discard

proc handshakeCompleted(connection: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  connection.install1RttKeys(zeroKey, zeroKey)

proc newClientConnection*(local, remote: TransportAddress): Connection =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.client_initial = clientInitial
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.decrypt = dummyDecrypt
  callbacks.encrypt = dummyEncrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.recv_crypto_data = receiveCryptoData
  callbacks.update_key = updateKey
  callbacks.handshake_completed = handshakeCompleted

  let settings = defaultSettings()
  let source = randomConnectionId().toCid
  let destination = randomConnectionId().toCid
  let path = newPath(local, remote)

  var conn: ptr ngtcp2_conn
  assert 0 == ngtcp2_conn_client_new(
    addr conn,
    unsafeAddr destination,
    unsafeAddr source,
    path.toPathPtr,
    cast[uint32](NGTCP2_PROTO_VER),
    addr callbacks,
    unsafeAddr settings,
    nil,
    nil
  )

  Connection(conn: conn, path: path)
