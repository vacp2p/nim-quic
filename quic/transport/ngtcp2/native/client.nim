import ngtcp2
import bearssl/rand
import ../../../errors
import ../../version
import ../../../basics
import ../../connectionid
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
import std/[sets, sequtils]

proc newNgtcp2Client*(
    tlsContext: PicoTLSContext,
    local, remote: TransportAddress,
    rng: ref HmacDrbgContext,
): Ngtcp2Connection =
  let path = newPath(local, remote)
  let nConn = newConnection(path, rng)

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

  var settings = defaultSettings(rng)
  var transportParams = defaultTransportParameters()
  settings.initial_ts = now()
  let source = randomConnectionId(rng).toCid
  let destination = randomConnectionId(rng).toCid

  var conn: ptr ngtcp2_conn
  var ret = ngtcp2_conn_client_new_versioned(
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
    addr nConn[],
  )
  if ret != 0:
    raise newException(QuicError, "could not create new client versioned conn: " & $ret)

  let cptls: ptr ngtcp2_crypto_picotls_ctx = create(ngtcp2_crypto_picotls_ctx)

  ngtcp2_crypto_picotls_ctx_init(cptls)

  var tls = tlsContext.newConnection(false)
  cptls.ptls = tls.conn

  var addExtensions = cast[ptr UncheckedArray[ptls_raw_extension_t]](alloc(
    ptls_raw_extension_t.sizeof * 2
  ))
  addExtensions[0] = ptls_raw_extension_t(type_field: high(uint16))
  addExtensions[1] = ptls_raw_extension_t(type_field: high(uint16))

  var alpn = cast[ptr UncheckedArray[ptls_iovec_t]](alloc(
    ptls_iovec_t.sizeof * len(tlsContext.alpn)
  ))
  let clientALPN = tlsContext.alpn.toSeq()
  for i in 0 ..< clientALPN.len:
    var proto = clientALPN[i]
    alpn[i].len = csize_t(clientALPN[i].len)
    var base = alloc(clientALPN[i].len)
    copyMem(base, proto[0].unsafeAddr, clientALPN[i].len)
    alpn[i].base = cast[ptr uint8](base)

  cptls.handshake_properties = ptls_handshake_properties_t(
    anon0: ptls_handshake_properties_t_anon0_t(
      client: ptls_handshake_properties_t_anon0_t_client_t(
        negotiated_protocols: ptls_handshake_properties_t_anon0_t_client_t_negotiated_protocols_t(
          list: alpn[0].addr, count: csize_t(clientALPN.len)
        )
      )
    ),
    additional_extensions: addExtensions[0].addr,
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

  ret = ngtcp2_crypto_picotls_configure_client_session(cptls, conn)
  if ret != 0:
    raise newException(QuicError, "could not configure client session: " & $ret)

  nConn.conn = Opt.some(conn)
  nConn.tlsContext = tlsContext
  nConn.tlsConn = tls
  nConn.cptls = cptls
  nConn.connref = connref
  nConn
