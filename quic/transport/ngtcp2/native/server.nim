import pkg/ngtcp2
import pkg/nimcrypto

import ../../../basics
import ../../../helpers/openarray
import ../../packets
import ../../version
import ./encryption
import ./ids
import ./settings
import ./cryptodata
import ./connection
import ./path
import ./rand
import ./streams
import ./timestamp
import ./handshake
import ./parsedatagram



proc newNgtcp2Server*(local, remote: TransportAddress,
                     source, destination: ngtcp2_cid): Ngtcp2Connection =
  var callbacks: ngtcp2_callbacks
  callbacks.recv_client_initial =  ngtcp2_crypto_recv_client_initial_cb
  callbacks.recv_crypto_data =  ngtcp2_crypto_recv_crypto_data_cb
  callbacks.delete_crypto_aead_ctx = ngtcp2_crypto_delete_crypto_aead_ctx_cb
  callbacks.delete_crypto_cipher_ctx = ngtcp2_crypto_delete_crypto_cipher_ctx_cb
  callbacks.get_path_challenge_data = ngtcp2_crypto_get_path_challenge_data_cb
  callbacks.version_negotiation = ngtcp2_crypto_version_negotiation_cb
  callbacks.rand = onRand

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
    addr transportParams,
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
