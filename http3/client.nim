import strformat
import tables
import results
import chronos
import chronicles
import ../quic/api
import nghttp3
import ngtcp2
import ./errors
import ./settings
import ./request_stream

logScope:
  topics = "http3 client"

type HTTP3Client* = ref object
  quicConn: Connection
  tcp2Conn: ptr ngtcp2_conn
  http3Conn: ptr nghttp3_conn
  settings: Opt[HTTP3Settings] = Opt.none(HTTP3Settings)
  settingsFut: Future[HTTP3Settings]
  lastError: ngtcp2_ccerr
  streams: Table[int64, HTTP3RequestStream]

template withTcp2Conn(): untyped =
  if client.tcp2Conn.isNil:
    return NGHTTP3_ERR_CALLBACK_FAILURE

proc httpConsume(client: ptr HTTP3Client, streamID: int64, consumed: csize_t) =
  discard ngtcp2_conn_extend_max_stream_offset(client.tcp2Conn, streamID, consumed)
  ngtcp2_conn_extend_max_offset(client.tcp2Conn, consumed)

proc httpWriteData(
    client: ptr HTTP3Client, streamID: int64, buf: ptr uint8, buflen: csize_t
) =
  if not client.streams.hasKey(streamID):
    trace "cant write data for nonexistent stream"
    return

  let stream = client.streams[streamID]
  stream.writeData(buf, buflen)

proc streamCloseCB(
    client: ptr HTTP3Client,
    conn: ptr nghttp3_conn,
    streamID: int64,
    appErrorCode: uint64,
): cint {.cdecl.} =
  # It is called when a stream is closed. It is useful to free resources allocated for a stream.
  # QUIC application error code `appErrorCode` indicates the reason of this closure.
  #
  # The implementation of this callback must return 0 if it succeeds.
  # Any values other than 0 is treated as macro:`NGHTTP3_ERR_CALLBACK_FAILURE`.
  withTcp2Conn()

  let rv = nghttp3_conn_close_stream(conn, streamID, appErrorCode)
  if rv == 0:
    return 0
  elif rv == NGHTTP3_ERR_STREAM_NOT_FOUND:
    # We have to handle the case when stream opened but no data is transferred. 
    # In this case, nghttp3_conn_close_stream might return error.
    if ngtcp2_is_bidi_stream(streamID) == 0:
      ngtcp2_conn_extend_max_streams_uni(client.tcp2Conn, 1)
    return 0
  else:
    let quicAppErrCode = nghttp3_err_infer_quic_app_error_code(rv)
    ngtcp2_ccerr_set_application_error(client.lastError.addr, quicAppErrCode, nil, 0)
    return NGHTTP3_ERR_CALLBACK_FAILURE

proc recvDataCB(
    client: ptr HTTP3Client,
    conn: ptr nghttp3_conn,
    streamID: int64,
    buf: ptr uint8,
    buflen: csize_t,
): cint {.cdecl.} =
  # It is a callback function which is invoked when a part of request or response body 
  # on stream identified by `streamID` is received. `buf` points to the received data, and
  # and its length is `buflen`.
  #
  # The application is responsible for increasing flow control credit 
  # (say, increasing by `datalen` bytes).
  #
  # The implementation of this callback must return 0 if it succeeds.
  # Any values other than 0 is treated as macro:`NGHTTP3_ERR_CALLBACK_FAILURE`.
  withTcp2Conn()

  client.httpConsume(streamID, buflen)
  client.httpWriteData(streamID, buf, buflen)

  return 0

proc deferredConsumeCB(
    client: ptr HTTP3Client, conn: ptr nghttp3_conn, streamID: int64, consumed: csize_t
): cint {.cdecl.} =
  withTcp2Conn()

  client.httpConsume(streamID, consumed)

  return 0

proc stopSendingCB(
    client: ptr HTTP3Client,
    conn: ptr nghttp3_conn,
    streamID: int64,
    appErrorCode: uint64,
): cint {.cdecl.} =
  withTcp2Conn()

  let rv = ngtcp2_conn_shutdown_stream_read(client.tcp2Conn, 0, streamID, appErrorCode)
  if rv != 0:
    trace "ngtcp2_conn_shutdown_stream_read returned error ", err = nghttp3_strerror(rv)
    return NGHTTP3_ERR_CALLBACK_FAILURE

  return 0

proc resetStreamCB(
    client: ptr HTTP3Client,
    conn: ptr nghttp3_conn,
    streamID: int64,
    appErrorCode: uint64,
): cint {.cdecl.} =
  withTcp2Conn()

  let rv = ngtcp2_conn_shutdown_stream_write(client.tcp2Conn, 0, streamID, appErrorCode)
  if rv != 0:
    trace "ngtcp2_conn_shutdown_stream_write returned error ",
      err = nghttp3_strerror(rv)
    return NGHTTP3_ERR_CALLBACK_FAILURE

  return 0

proc shutdownCB(
    client: ptr HTTP3Client, conn: ptr nghttp3_conn, streamID: int64
): cint {.cdecl.} =
  return 0

proc recvSettingsCB(
    client: ptr HTTP3Client, conn: ptr nghttp3_conn, settings: ptr nghttp3_settings
): cint {.cdecl.} =
  var http3Settings = HTTP3Settings()
  http3Settings.enableDatagrams = settings.h3_datagram != 0
  http3Settings.enableExtendedConnect = settings.enable_connect_protocol != 0

  client.settings = Opt.some(http3Settings)
  client.settingsFut.complete(http3Settings)

  return 0

proc beginHeadersCB(
    client: ptr HTTP3Client, conn: ptr nghttp3_conn, streamID: int64
): cint {.cdecl.} =
  return 0

proc recvHeadersCB(
    client: ptr HTTP3Client,
    conn: ptr nghttp3_conn,
    streamID: int64,
    token: int32,
    name: ptr nghttp3_rcbuf,
    value: ptr nghttp3_rcbuf,
    flags: uint8,
): cint {.cdecl.} =
  return 0

proc endHeadersCB(
    client: ptr HTTP3Client, conn: ptr nghttp3_conn, streamID: int64, fin: int
): cint {.cdecl.} =
  return 0

proc makeNgHTTP3Callbacks(): nghttp3_callbacks =
  var ngCallbacks: nghttp3_callbacks

  ngCallbacks.stream_close = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      appErrorCode: uint64,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "stream_close"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.streamCloseCB(conn, streamID, appErrorCode)

  ngCallbacks.recv_data = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      buf: ptr uint8,
      buflen: csize_t,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "recv_data"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.recvDataCB(conn, streamID, buf, buflen)

  ngCallbacks.deferred_consume = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      consumed: csize_t,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "deferred_consume"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.deferredConsumeCB(conn, streamID, consumed)

  ngCallbacks.stop_sending = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      appErrorCode: uint64,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "stop_sending"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.stopSendingCB(conn, streamID, appErrorCode)

  ngCallbacks.reset_stream = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      appErrorCode: uint64,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "reset_stream"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.resetStreamCB(conn, streamID, appErrorCode)

  ngCallbacks.shutdown = proc(
      conn: ptr nghttp3_conn, streamID: int64, userData: pointer
  ): cint {.cdecl.} =
    echo "shutdown"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.shutdownCB(conn, streamID)

  ngCallbacks.recv_settings = proc(
      conn: ptr nghttp3_conn, setting: ptr nghttp3_settings, userData: pointer
  ): cint {.cdecl.} =
    echo "recv_settings"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.recvSettingsCB(conn, setting)

  ngCallbacks.begin_headers = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "begin_headers"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.beginHeadersCB(conn, streamID)

  ngCallbacks.recv_header = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      token: int32,
      name: ptr nghttp3_rcbuf,
      value: ptr nghttp3_rcbuf,
      flags: uint8,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "recv_header"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.recvHeadersCB(conn, streamID, token, name, value, flags)

  ngCallbacks.end_headers = proc(
      conn: ptr nghttp3_conn,
      streamID: int64,
      fin: cint,
      userData: pointer,
      streamUserData: pointer,
  ): cint {.cdecl.} =
    echo "end_headers"
    let callbacks = cast[ptr HTTP3Client](userData)
    return callbacks.endHeadersCB(conn, streamID, fin)

  return ngCallbacks

proc createNgHTTP3Conn*(
    client: ptr HTTP3Client
): ptr nghttp3_conn {.raises: [HTTP3Error].} =
  # make callback
  let ngCallbacks = makeNgHTTP3Callbacks()

  # make settings
  var settings: nghttp3_settings
  nghttp3_settings_default_versioned(NGHTTP3_SETTINGS_V1, addr settings)
  settings.qpack_max_dtable_capacity = 4096
  settings.qpack_blocked_streams = 100

  var mem = nghttp3_mem_default()

  var conn: ptr nghttp3_conn
  let rv = nghttp3_conn_client_new_versioned(
    addr conn,
    NGHTTP3_CALLBACKS_V1,
    addr ngCallbacks,
    NGHTTP3_SETTINGS_V1,
    addr settings,
    mem,
    client,
  )
  if rv != 0:
    raise newException(
      HTTP3Error,
      fmt"failed to initialize nghttp3 client (code: {rv}, err: {nghttp3_strerror(rv)})",
    )

  return conn

proc setupStreams(
    tcp2Conn: ptr ngtcp2_conn, http3Conn: ptr nghttp3_conn
) {.raises: [HTTP3Error].} =
  doAssert not tcp2Conn.isNil, "ngtcp2 connection can't be nil"
  doAssert not http3Conn.isNil, "nghttp3 connection can't be nil"

  if ngtcp2_conn_get_streams_uni_left(tcp2Conn) < 3:
    raise newException(HTTP3Error, "does not allow at least 3 unidirectional streams")

  var ctrlStreamID: int64

  var rv = ngtcp2_conn_open_uni_stream(tcp2Conn, ctrlStreamID.addr, nil)
  if rv != 0:
    raise newException(
      HTTP3Error,
      fmt"failed to open uni stream (code: {rv}, err: {ngtcp2_strerror(rv)})",
    )

  rv = nghttp3_conn_bind_control_stream(http3Conn, ctrlStreamID)
  if rv != 0:
    raise newException(
      HTTP3Error,
      fmt"failed to bind http3 control stream (code: {rv}, err: {nghttp3_strerror(rv)})",
    )

  trace "http3 control stream ", streamID = ctrlStreamID

  var qpackEncStreamID, qpackDecStreamID: int64

  rv = ngtcp2_conn_open_uni_stream(tcp2Conn, qpackEncStreamID.addr, nil)
  if rv != 0:
    raise newException(
      HTTP3Error,
      fmt"failed to open uni stream (code: {rv}, err: {ngtcp2_strerror(rv)})",
    )

  rv = ngtcp2_conn_open_uni_stream(tcp2Conn, qpackDecStreamID.addr, nil)
  if rv != 0:
    raise newException(
      HTTP3Error,
      fmt"failed to open uni stream (code: {rv}, err: {ngtcp2_strerror(rv)})",
    )

  rv = nghttp3_conn_bind_qpack_streams(http3Conn, qpackEncStreamID, qpackDecStreamID)
  if rv != 0:
    raise newException(
      HTTP3Error,
      fmt"failed to bind http3 qpac stream (code: {rv}, err: {nghttp3_strerror(rv)})",
    )

proc init*(
    t: typedesc[HTTP3Client], quicConn: Connection
): HTTP3Client {.raises: [HTTP3Error].} =
  let tcp2Conn = quicConn.ngtcp2Connection().conn.valueOr:
    raise newException(HTTP3Error, "ngtcp connection no longer exists")

  var client = HTTP3Client()
  client.quicConn = quicConn
  client.tcp2Conn = tcp2Conn
  client.streams = initTable[int64, HTTP3RequestStream]()
  client.http3Conn = createNgHTTP3Conn(client.addr)
  client.settingsFut = newFuture[HTTP3Settings]()
  setupStreams(tcp2Conn, client.http3Conn)

  return client

proc destroy*(c: HTTP3Client) =
  if not c.http3Conn.isNil:
    nghttp3_conn_del(c.http3Conn)
    c.http3Conn = nil

proc openRequestStream*(
    c: HTTP3Client
): Future[HTTP3RequestStream] {.async: (raises: [HTTP3Error, CancelledError]).} =
  let quicStream =
    try:
      await c.quicConn.openStream(unidirectional = false)
    except CancelledError as e:
      raise e
    except CatchableError as e:
      raise (ref HTTP3Error)(msg: e.msg, parent: e)

  return HTTP3RequestStream.init(quicStream)

proc settings*(c: HTTP3Client): Future[HTTP3Settings] =
  return c.settingsFut
