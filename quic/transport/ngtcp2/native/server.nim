import pkg/ngtcp2
import ../../../basics
import ../../../helpers/openarray
import ../../packets
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
                         level: ngtcp2_crypto_level,
                         offset: uint64,
                         data: ptr uint8,
                         datalen: uint,
                         userData: pointer): cint {.cdecl.} =
  if level == NGTCP2_CRYPTO_LEVEL_INITIAL:
    connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_INITIAL)
    connection.installHandshakeKeys()
    connection.handleCryptoData(toOpenArray(data, datalen))
    connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_HANDSHAKE)
    connection.install1RttKeys()
  if level == NGTCP2_CRYPTO_LEVEL_HANDSHAKE:
    connection.submitCryptoData(NGTCP2_CRYPTO_LEVEL_APP)
    ngtcp2_conn_handshake_completed(connection)

proc newNgtcp2Server*(local, remote: TransportAddress,
                     source, destination: ngtcp2_cid): Ngtcp2Connection =
  var callbacks: ngtcp2_conn_callbacks
  callbacks.recv_client_initial = onReceiveClientInitial
  callbacks.recv_crypto_data = onReceiveCryptoData
  installConnectionIdCallback(callbacks)
  installEncryptionCallbacks(callbacks)
  installServerHandshakeCallback(callbacks)
  installStreamCallbacks(callbacks)

  var settings = defaultSettings()
  settings.transport_params.original_dcid = destination
  settings.initial_ts = now()

  let id = randomConnectionId().toCid
  let path = newPath(local, remote)

  result = newConnection(path)
  var conn: ptr ngtcp2_conn

  doAssert 0 == ngtcp2_conn_server_new(
    addr conn,
    unsafeAddr source,
    unsafeAddr id,
    path.toPathPtr,
    cast[uint32](NGTCP2_PROTO_VER_MAX),
    addr callbacks,
    addr settings,
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
