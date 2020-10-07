import quic
import quic/openarray
import ngtcp2
import encrypt
import decrypt
import hp
import ids
import keys
import settings
import crypto
import connection

let zeroKey = Key()

proc receiveClientInitial(connection: ptr ngtcp2_conn, dcid: ptr ngtcp2_cid, userData: pointer): cint {.cdecl.} =
  connection.install0RttKey(zeroKey)
  connection.installHandshakeKeys(zeroKey, zeroKey)

proc receiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  connection.handleCryptoData(toOpenArray(data, datalen))
  connection.submitCryptoData()
  ngtcp2_conn_handshake_completed(connection)

proc updateKey(conn: ptr ngtcp2_conn, rx_secret: ptr uint8, tx_secret: ptr uint8, rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, rx_iv: ptr uint8, tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, tx_iv: ptr uint8, current_rx_secret: ptr uint8, current_tx_secret: ptr uint8, secretlen: uint, user_data: pointer): cint {.cdecl} =
  discard

proc handshakeCompleted(connection: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  connection.install1RttKeys(zeroKey, zeroKey)

proc setupServer*(path: ngtcp2_path, source, destination: ngtcp2_cid): Connection =
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
  settings.transport_params.original_dcid = destination

  let id = randomConnectionId()

  var conn: ptr ngtcp2_conn
  assert 0 == ngtcp2_conn_server_new(
    addr conn,
    unsafeAddr source,
    unsafeAddr id,
    unsafeAddr path,
    cast[uint32](NGTCP2_PROTO_VER),
    addr callbacks,
    addr settings,
    nil,
    nil
  )

  Connection(conn: conn, path: path)

proc extractIds(datagram: Datagram): tuple[source, destination: ngtcp2_cid] =
  var packetVersion: uint32
  var packetDestinationId: ptr uint8
  var packetDestinationIdLen: uint
  var packetSourceId: ptr uint8
  var packetSourceIdLen: uint
  assert 0 == ngtcp2_pkt_decode_version_cid(addr packetVersion, addr packetDestinationId, addr packetDestinationIdLen, addr packetSourceId, addr packetSourceIdLen, unsafeAddr datagram[0], datagram.len.uint, DefaultConnectionIdLength)
  result.source = connectionId(packetSourceId, packetSourceIdLen)
  result.destination = connectionId(packetDestinationId, packetDestinationIdLen)

proc setupServer*(path: ngtcp2_path, datagram: Datagram): Connection =
  let (source, destination) = extractIds(datagram)
  setupServer(path, source, destination)
