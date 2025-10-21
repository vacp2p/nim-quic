import chronicles
import ngtcp2

import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../../tlsbackend
import ../native/connection
import ../native/streams
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

method close(state: OpenConnection) {.async: (raises: [CancelledError, QuicError]).}

method enter(
    state: OpenConnection, connection: QuicConnection
) {.raises: [QuicError].} =
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

  state.ngtcp2Connection.onSend = proc(datagram: Datagram) {.raises: [QuicError].} =
    try:
      connection.outgoing.putNoWait(datagram)
    except AsyncQueueFullError:
      raise newException(QuicError, "Outgoing queue is full")

  state.ngtcp2Connection.onIncomingStream = proc(stream: Stream) =
    state.streams.add(stream)
    connection.incoming.putNoWait(stream)
  state.ngtcp2Connection.onHandshakeDone = proc() =
    state.handshakeCompleted = true
    state.derCertificates = state.ngtcp2Connection.certificates()
    connection.handshake.fire()

  state.ngtcp2Connection.onTimeout = proc() {.gcsafe, raises: [].} =
    connection.timeout.fire()
    state.streams.expireAll()
    discard state.close()

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

method send(state: OpenConnection) {.raises: [QuicError].} =
  state.ngtcp2Connection.send()

method receive(state: OpenConnection, datagram: sink Datagram) {.raises: [QuicError].} =
  var errCode = 0
  var errMsg = ""
  try:
    state.ngtcp2Connection.receive(datagram)
  except Ngtcp2Error as exc:
    errCode = exc.code
    errMsg = exc.msg
    trace "ngtcp2 error on receive", code = errCode, msg = errMsg
  finally:
    let quicConnection = state.quicConnection.valueOr:
      return
    if state.ngtcp2Connection.isDraining:
      let ids = state.ids
      let duration = state.ngtcp2Connection.closingDuration()
      let draining = newDrainingConnection(ids, duration, state.derCertificates)
      quicConnection.switch(draining)
      discard draining.close()

      if not state.handshakeCompleted:
        # When a server for any reason decides that the certificate is
        # not valid, ngtcp2 will return an ERR_DRAINING and no other
        # indication that the handshake failed, so we emit a custom
        # error instead to indicate the handshake failed
        quicConnection.error.emit("ERR_HANDSHAKE_FAILED")
    elif errCode != 0 and errCode != NGTCP2_ERR_DROP_CONN:
      quicConnection.error.emit(errMsg)
      discard state.close()

method openStream(
    state: OpenConnection, unidirectional: bool
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  let quicConnection = state.quicConnection.valueOr:
    raise newException(QuicError, "connection is closed")
  await quicConnection.handshake.wait()
  result = state.ngtcp2Connection.openStream(unidirectional = unidirectional)
  state.streams.add(result)

method close(state: OpenConnection) {.async: (raises: [CancelledError, QuicError]).} =
  let quicConnection = state.quicConnection.valueOr:
    return
  let finalDatagram = state.ngtcp2Connection.close()
  let duration = state.ngtcp2Connection.closingDuration()
  let ids = state.ids
  let closing =
    newClosingConnection(finalDatagram, ids, duration, state.derCertificates)
  quicConnection.switch(closing)
  await closing.close()

method drop(state: OpenConnection) {.async: (raises: [CancelledError, QuicError]).} =
  trace "Dropping OpenConnection state"
  let quicConnection = state.quicConnection.valueOr:
    return
  let disconnecting = newDisconnectingConnection(state.ids, state.derCertificates)
  quicConnection.switch(disconnecting)
  await disconnecting.drop()
