import pkg/ngtcp2
import bearssl/rand
import ../../../basics
import ../../../errors
import ../../packets
import ../../version
import ./encryption
import ./ids
import ./settings
import ./connection
import ./path
import ./picotls
import ./rand
import ./streams
import ./timestamp
import ./handshake
import ./parsedatagram

proc newNgtcp2Server*(
    tlsContext: PicoTLSContext,
    local, remote: TransportAddress,
    source, destination: ngtcp2_cid,
    rng: ref HmacDrbgContext,
): Ngtcp2Connection =
  let path = newPath(local, remote)
  let nConn = newConnection(path, rng)

  var callbacks: ngtcp2_callbacks
  callbacks.recv_client_initial = ngtcp2_crypto_recv_client_initial_cb
  callbacks.recv_crypto_data = ngtcp2_crypto_recv_crypto_data_cb
  callbacks.delete_crypto_aead_ctx = ngtcp2_crypto_delete_crypto_aead_ctx_cb
  callbacks.delete_crypto_cipher_ctx = ngtcp2_crypto_delete_crypto_cipher_ctx_cb
  callbacks.get_path_challenge_data = ngtcp2_crypto_get_path_challenge_data_cb
  callbacks.version_negotiation = ngtcp2_crypto_version_negotiation_cb
  callbacks.rand = onRand

  installConnectionIdCallback(callbacks)
  installEncryptionCallbacks(callbacks)
  installServerHandshakeCallback(callbacks)
  installStreamCallbacks(callbacks)

  var settings = defaultSettings(rng)
  var transportParams = defaultTransportParameters()
  transportParams.original_dcid = destination
  transportParams.original_dcid_present = 1
  settings.initial_ts = now()

  let id = randomConnectionId(rng = rng).toCid

  var conn: ptr ngtcp2_conn
  var ret = ngtcp2_conn_server_new_versioned(
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
    addr nConn[],
  )
  if ret != 0:
    raise newException(QuicError, "could not create new server versioned conn: " & $ret)

  let cptls: ptr ngtcp2_crypto_picotls_ctx = create(ngtcp2_crypto_picotls_ctx)

  ngtcp2_crypto_picotls_ctx_init(cptls)

  var tls = tlsContext.newConnection(true)
  cptls.ptls = tls.conn

  var addExtensions = cast[ptr UncheckedArray[ptls_raw_extension_t]](alloc(
    ptls_raw_extension_t.sizeof * 2
  ))
  addExtensions[0] = ptls_raw_extension_t(type_field: high(uint16))
  addExtensions[1] = ptls_raw_extension_t(type_field: high(uint16))
  cptls.handshake_properties = ptls_handshake_properties_t(
    additional_extensions: cast[ptr ptls_raw_extension_t](addExtensions)
  )

  ngtcp2_conn_set_tls_native_handle(conn, cptls)

  var connref = create(ngtcp2_crypto_conn_ref)
  connref.user_data = conn
  connref.get_conn = proc(
      connRef: ptr ngtcp2_crypto_conn_ref
  ): ptr ngtcp2_conn {.cdecl.} =
    cast[ptr ngtcp2_conn](connRef.user_data)

  var dataPtr = ptls_get_data_ptr(tls.conn)
  dataPtr[] = connref

  ret = ngtcp2_crypto_picotls_configure_server_session(cptls)
  if ret != 0:
    raise newException(QuicError, "could not configure server session: " & $ret)

  nConn.conn = Opt.some(conn)
  nConn.tlsConn = tls
  nConn.cptls = cptls
  nConn.connref = connref
  nConn

proc extractIds(datagram: openArray[byte]): tuple[source, dest: ngtcp2_cid] =
  let info = parseDatagram(datagram)
  (source: info.source.toCid, dest: info.destination.toCid)

proc newNgtcp2Server*(
    tlsContext: PicoTLSContext,
    local, remote: TransportAddress,
    datagram: openArray[byte],
    rng: ref HmacDrbgContext,
): Ngtcp2Connection =
  let (source, destination) = extractIds(datagram)
  newNgtcp2Server(tlsContext, local, remote, source, destination, rng)
