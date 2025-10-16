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
import ./rand
import ./streams
import ./timestamp
import ./handshake
import ./parsedatagram
import ./types

proc newNgtcp2Server*(
    tlsContext: TLSContext,
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
    addr source,
    addr id,
    path.toPathPtr,
    CurrentQuicVersion,
    NGTCP2_CALLBACKS_V1,
    addr callbacks,
    NGTCP2_SETTINGS_V2,
    addr settings,
    NGTCP2_TRANSPORT_PARAMS_V1,
    addr transportParams,
    nil,
    cast[pointer](nConn),
  )
  if ret != 0:
    raise newException(QuicError, "could not create new server versioned conn: " & $ret)

  nConn.conn = Opt.some(conn)

  let ssl = SSL_new(tlsContext.context)
  if ssl.isNil:
    raise newException(QuicError, "SSL_new" & $ERR_error_string(ERR_get_error(), nil))

  nConn.connref = create(ngtcp2_crypto_conn_ref)
  nConn.connref.user_data = cast[pointer](nConn)
  nConn.connref.get_conn = proc(
      connRef: ptr ngtcp2_crypto_conn_ref
  ): ptr ngtcp2_conn {.cdecl.} =
    let n = cast[Ngtcp2Connection](connRef.user_data)
    return n.conn.get()

  discard SSL_set_ex_data(ssl, 0, nConn.connref)
  SSL_set_accept_state(ssl)

  ngtcp2_conn_set_tls_native_handle(nConn.conn.get(), ssl)

  nConn.tlsContext = tlsContext
  nConn.ssl = ssl
  nConn

proc newNgtcp2Server*(
    tlsContext: TLSContext,
    local, remote: TransportAddress,
    datagram: openArray[byte],
    rng: ref HmacDrbgContext,
): Ngtcp2Connection =
  let info = parseDatagramInfo(datagram)
  newNgtcp2Server(
    tlsContext, local, remote, info.source.toCid, info.destination.toCid, rng
  )
