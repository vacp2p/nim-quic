import ngtcp2
import nimcrypto
import results
import ../../version
import ../../../basics
import ../../connectionid
import ../../tlsbackend
import ./ids
import ./encryption
import ./settings
import ./connection
import ./path
import ./picotls
import ./rand
import ./streams
import ./timestamp
import ./handshake

proc getConn(connRef: ptr ngtcp2_crypto_conn_ref) : ptr ngtcp2_conn {.cdecl.} =
  cast[ptr ngtcp2_conn](connRef.user_data)

proc newNgtcp2Client*(tlsBackend: TLSBackend, local, remote: TransportAddress): Result[Ngtcp2Connection, string] =
  var callbacks: ngtcp2_callbacks
  callbacks.client_initial = ngtcp2_crypto_client_initial_cb
  callbacks.recv_crypto_data = ngtcp2_crypto_recv_crypto_data_cb
  callbacks.recv_retry = ngtcp2_crypto_recv_retry_cb
  callbacks.delete_crypto_aead_ctx = ngtcp2_crypto_delete_crypto_aead_ctx_cb
  callbacks.delete_crypto_cipher_ctx = ngtcp2_crypto_delete_crypto_cipher_ctx_cb
  callbacks.get_path_challenge_data = ngtcp2_crypto_get_path_challenge_data_cb
  callbacks.version_negotiation = ngtcp2_crypto_version_negotiation_cb
  callbacks.rand = onRand

  installConnectionIdCallback(callbacks)
  installEncryptionCallbacks(callbacks)
  installClientHandshakeCallback(callbacks)
  installStreamCallbacks(callbacks)

  var ret = ngtcp2_crypto_picotls_configure_client_context(tlsBackend.picoTLS.context)
  if ret != 0:
    return err("could not configure client context: " & $ret)

  var settings = defaultSettings()
  var transportParams = defaultTransportParameters()
  settings.initial_ts = now()
  let source = randomConnectionId().toCid
  let destination = randomConnectionId().toCid
  let path = newPath(local, remote)

  let nConn = newConnection(path)

  # TODO: ptls_openssl_dispose_sign_certificate(addr sign_cert_) on destroy
  # TODO: figure out if clients use certificates in quic in js / rust

  var conn: ptr ngtcp2_conn
  ret = ngtcp2_conn_client_new_versioned(
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
    addr nConn[]
  )
  if ret != 0:
    return err("could not create new versioned conn: " & $ret)


  let cptls: ptr ngtcp2_crypto_picotls_ctx = create(ngtcp2_crypto_picotls_ctx) # TODO: free

  ngtcp2_crypto_picotls_ctx_init(cptls) 

  var tls = tlsBackend.picoTLS.newConnection(false) # free?
  cptls.ptls = tls.conn
  
  var addExtensions = cast[ptr UncheckedArray[ptls_raw_extension_t]](alloc(ptls_raw_extension_t.sizeof*2))
  addExtensions[0] = ptls_raw_extension_t(type_field: high(uint16))
  addExtensions[1] = ptls_raw_extension_t(type_field: high(uint16))
  cptls.handshake_properties = ptls_handshake_properties_t( # TODO: free
    additional_extensions: cast[ptr ptls_raw_extension_t](addExtensions)
  )

  ngtcp2_conn_set_tls_native_handle(conn, cptls)

  var connref = create(ngtcp2_crypto_conn_ref) # TODO: free
  connref.user_data = conn
  connref.get_conn = getConn

  var dataPtr = ptls_get_data_ptr(tls.conn)
  dataPtr[] = addr connref

  ret = ngtcp2_crypto_picotls_configure_client_session(cptls, conn)
  if ret != 0:
    return err("could not configure client session: " & $ret)
  
  nConn.conn = Opt.some(conn)
  nConn.tlsConn = tls
  nConn.cptls = cptls
  nConn.connref = connref
  
  ok(nConn)
