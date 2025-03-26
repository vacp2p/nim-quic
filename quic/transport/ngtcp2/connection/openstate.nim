import chronicles
import bearssl/rand
import ngtcp2

import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../../tlsbackend
import ../native/connection
import ../native/streams
import ../native/client
import ../native/server
import ../native/errors
import ./closingstate
import ./drainingstate
import ./disconnectingstate
import ./openstreams

logScope:
  topics = "quic openstate"

type OpenConnection* = ref object of ConnectionState
  quicConnection: Opt[QuicConnection]
  handshakeCompleted: bool
  ngtcp2Connection: Ngtcp2Connection
  streams: OpenStreams

proc newOpenConnection*(ngtcp2Connection: Ngtcp2Connection): OpenConnection =
  OpenConnection(ngtcp2Connection: ngtcp2Connection, streams: OpenStreams.new)

proc openClientConnection*(
    tlsBackend: TLSBackend, local, remote: TransportAddress, rng: ref HmacDrbgContext
): OpenConnection =
  let ngtcp2Conn = newNgtcp2Client(tlsBackend.picoTLS, local, remote, rng)
  newOpenConnection(ngtcp2Conn)

proc openServerConnection*(
    tlsBackend: TLSBackend,
    local, remote: TransportAddress,
    datagram: Datagram,
    rng: ref HmacDrbgContext,
): OpenConnection =
  newOpenConnection(
    newNgtcp2Server(tlsBackend.picoTLS, local, remote, datagram.data, rng)
  )

{.push locks: "unknown".}

method close(state: OpenConnection) {.async.}

method enter(state: OpenConnection, connection: QuicConnection) =
  trace "Entering OpenConnection state"
  procCall enter(ConnectionState(state), connection)
  state.quicConnection = Opt.some(connection)
  # Workaround weird bug
  var onNewId = proc(id: ConnectionId) =
    if isNil(connection.onNewId):
      return
    connection.onNewId(id)

  var onRemoveId = proc(id: ConnectionId) =
    if isNil(connection.onRemoveId):
      return
    connection.onRemoveId(id)

  state.ngtcp2Connection.onNewId = Opt.some(onNewId)
  state.ngtcp2Connection.onRemoveId = Opt.some(onRemoveId)

  state.ngtcp2Connection.onSend = proc(datagram: Datagram) =
    errorAsDefect:
      connection.outgoing.putNoWait(datagram)

  state.ngtcp2Connection.onIncomingStream = proc(stream: Stream) =
    state.streams.add(stream)
    connection.incoming.putNoWait(stream)
  state.ngtcp2Connection.onHandshakeDone = proc() =
    state.handshakeCompleted = true
    connection.handshake.fire()

  state.ngtcp2Connection.onTimeout = proc() {.gcsafe, raises: [].} =
    try:
      connection.timeout.fire()
    except Ngtcp2ConnectionClosed:
      trace "connection closed"

  trace "Entered OpenConnection state"

method leave(state: OpenConnection) =
  trace "Leaving OpenConnection state"
  procCall leave(ConnectionState(state))
  state.streams.closeAll()
  state.ngtcp2Connection.destroy()
  state.quicConnection = Opt.none(QuicConnection)
  trace "Left OpenConnection state"

method ids(state: OpenConnection): seq[ConnectionId] {.raises: [].} =
  state.ngtcp2Connection.ids

method send(state: OpenConnection) =
  state.ngtcp2Connection.send()

method receive(state: OpenConnection, datagram: Datagram) =
  var errCode = 0
  var errMsg = ""
  try:
    state.ngtcp2Connection.receive(datagram)
  except Ngtcp2Error as exc:
    errCode = exc.code
    errMsg = exc.msg
    trace "ngtcp2 error on receive", code = errCode, msg = errMsg
  finally:
    var isDraining = state.ngtcp2Connection.isDraining
    let quicConnection = state.quicConnection.valueOr:
      return
    if isDraining:
      let ids = state.ids
      let duration = state.ngtcp2Connection.closingDuration()
      let draining = newDrainingConnection(ids, duration)
      quicConnection.switch(draining)
      asyncSpawn draining.close()

      if not state.handshakeCompleted:
        # When a server for any reason decides that the certificate is
        # not valid, ngtcp2 will return an ERR_DRAINING and no other
        # indication that the handshake failed, so we emit a custom
        # error instead to indicate the handshake failed
        quicConnection.error.emit("ERR_HANDSHAKE_FAILED")
    elif errCode != 0 and errCode != NGTCP2_ERR_DROP_CONN:
      quicConnection.error.emit(errMsg)
      asyncSpawn state.close()

method openStream(
    state: OpenConnection, unidirectional: bool
): Future[Stream] {.async.} =
  let quicConnection = state.quicConnection.valueOr:
    raise newException(QuicError, "connection is closed")
  await quicConnection.handshake.wait()
  result = state.ngtcp2Connection.openStream(unidirectional = unidirectional)
  state.streams.add(result)

method close(state: OpenConnection) {.async.} =
  let quicConnection = state.quicConnection.valueOr:
    return
  let finalDatagram = state.ngtcp2Connection.close()
  let duration = state.ngtcp2Connection.closingDuration()
  let ids = state.ids
  let closing = newClosingConnection(finalDatagram, ids, duration)
  quicConnection.switch(closing)
  await closing.close()

method drop(state: OpenConnection) {.async.} =
  trace "Dropping OpenConnection state"
  let quicConnection = state.quicConnection.valueOr:
    return
  let disconnecting = newDisconnectingConnection(state.ids)
  quicConnection.switch(disconnecting)
  await disconnecting.drop()
  trace "Dropped OpenConnection state"

{.pop.}
