import chronos
import ngtcp2
import ../packets
import ../openarray
import encryption
import ids
import keys
import settings
import cryptodata
import connection
import path
import errors
import streams
import timestamp


proc onReceiveClientInitial(connection: ptr ngtcp2_conn, dcid: ptr ngtcp2_cid, userData: pointer): cint {.cdecl.} =
  connection.install0RttKey()

proc onReceiveCryptoData(connection: ptr ngtcp2_conn, level: ngtcp2_crypto_level, offset: uint64, data: ptr uint8, datalen: uint, userData: pointer): cint {.cdecl.} =
  if level == NGTCP2_CRYPTO_LEVEL_INITIAL:
    connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_INITIAL)
    connection.installHandshakeKeys()
    connection.handleCryptoData(toOpenArray(data, datalen))
    connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_HANDSHAKE)
    connection.install1RttKeys()
  if level == NGTCP2_CRYPTO_LEVEL_HANDSHAKE:
    connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_APP)
    ngtcp2_conn_handshake_completed(connection)

proc onUpdateKey(conn: ptr ngtcp2_conn, rx_secret: ptr uint8, tx_secret: ptr uint8, rx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, rx_iv: ptr uint8, tx_aead_ctx: ptr ngtcp2_crypto_aead_ctx, tx_iv: ptr uint8, current_rx_secret: ptr uint8, current_tx_secret: ptr uint8, secretlen: uint, user_data: pointer): cint {.cdecl} =
  discard

proc onHandshakeCompleted(connection: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  cast[Connection](userData).handshake.fire()

proc newServerConnection(local, remote: TransportAddress, source, destination: ngtcp2_cid): Connection =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.recv_client_initial = onReceiveClientInitial
  callbacks.recv_crypto_data = onReceiveCryptoData
  callbacks.decrypt = dummyDecrypt
  callbacks.encrypt = dummyEncrypt
  callbacks.hp_mask = dummyHpMask
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.update_key = onUpdateKey
  callbacks.handshake_completed = onHandshakeCompleted
  callbacks.stream_open = onStreamOpen
  callbacks.recv_stream_data = onReceiveStreamData

  var settings = defaultSettings()
  settings.transport_params.original_dcid = destination
  settings.initial_ts = now()

  let id = randomConnectionId().toCid
  let path = newPath(local, remote)

  result = newConnection(path)

  doAssert 0 == ngtcp2_conn_server_new(
    addr result.conn,
    unsafeAddr source,
    unsafeAddr id,
    path.toPathPtr,
    cast[uint32](NGTCP2_PROTO_VER_MAX),
    addr callbacks,
    addr settings,
    nil,
    addr result[]
  )

proc extractIds(datagram: DatagramBuffer): tuple[source, destination: ngtcp2_cid] =
  var packetVersion: uint32
  var packetDestinationId: ptr uint8
  var packetDestinationIdLen: uint
  var packetSourceId: ptr uint8
  var packetSourceIdLen: uint
  checkResult ngtcp2_pkt_decode_version_cid(addr packetVersion, addr packetDestinationId, addr packetDestinationIdLen, addr packetSourceId, addr packetSourceIdLen, unsafeAddr datagram[0], datagram.len.uint, DefaultConnectionIdLength)
  result.source = toCid(packetSourceId, packetSourceIdLen)
  result.destination = toCid(packetDestinationId, packetDestinationIdLen)

proc newServerConnection*(local, remote: TransportAddress, datagram: DatagramBuffer): Connection =
  let (source, destination) = extractIds(datagram)
  newServerConnection(local, remote, source, destination)
