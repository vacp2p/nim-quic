import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../native/connection
import ../native/streams
import ../native/client
import ../native/server
import ./closingstate
import ./drainingstate
import ./disconnectingstate
import ./openstreams

type
  OpenConnection* = ref object of ConnectionState
    quicConnection: Option[QuicConnection]
    ngtcp2Connection: Ngtcp2Connection
    streams: OpenStreams

proc newOpenConnection*(ngtcp2Connection: Ngtcp2Connection): OpenConnection =
  OpenConnection(ngtcp2Connection: ngtcp2Connection, streams: OpenStreams.new)

proc openClientConnection*(local, remote: TransportAddress): OpenConnection =
  newOpenConnection(newNgtcp2Client(local, remote))

proc openServerConnection*(local, remote: TransportAddress,
                           datagram: Datagram): OpenConnection =
  newOpenConnection(newNgtcp2Server(local, remote, datagram.data))

{.push locks: "unknown".}

method enter(state: OpenConnection, connection: QuicConnection) =
  procCall enter(ConnectionState(state), connection)
  state.quicConnection = some connection
  state.ngtcp2Connection.onNewId = some proc(id: ConnectionId) =
    if isNil(connection.onNewId): return
    connection.onNewId(id)
  state.ngtcp2Connection.onRemoveId = some proc(id: ConnectionId) =
    if isNil(connection.onRemoveId): return
    connection.onRemoveId(id)
  state.ngtcp2Connection.onSend = proc(datagram: Datagram) =
    errorAsDefect:
      connection.outgoing.putNoWait(datagram)
  state.ngtcp2Connection.onIncomingStream = proc(stream: Stream) =
    state.streams.add(stream)
    connection.incoming.putNoWait(stream)
  state.ngtcp2Connection.onHandshakeDone = proc =
    connection.handshake.fire()

method leave(state: OpenConnection) =
  procCall leave(ConnectionState(state))
  state.streams.closeAll()
  state.ngtcp2Connection.destroy()
  state.quicConnection = QuicConnection.none

method ids(state: OpenConnection): seq[ConnectionId] {.upraises: [].} =
  state.ngtcp2Connection.ids

method send(state: OpenConnection) =
  state.ngtcp2Connection.send()

method receive(state: OpenConnection, datagram: Datagram) =
  state.ngtcp2Connection.receive(datagram)
  let quicConnection = state.quicConnection.getOr: return
  if state.ngtcp2Connection.isDraining:
    let duration = state.ngtcp2Connection.closingDuration()
    let ids = state.ids
    let draining = newDrainingConnection(ids, duration)
    quicConnection.switch(draining)
    asyncSpawn draining.close()

method openStream(state: OpenConnection,
                  unidirectional: bool): Future[Stream] {.async.} =
  let quicConnection = state.quicConnection.getOr:
    raise newException(QuicError, "connection is closed")
  await quicConnection.handshake.wait()
  result = state.ngtcp2Connection.openStream(unidirectional = unidirectional)
  state.streams.add(result)

method close(state: OpenConnection) {.async.} =
  let quicConnection = state.quicConnection.getOr: return
  let finalDatagram = state.ngtcp2Connection.close()
  let duration = state.ngtcp2Connection.closingDuration()
  let ids = state.ids
  let closing = newClosingConnection(finalDatagram, ids, duration)
  quicConnection.switch(closing)
  await closing.close()

method drop(state: OpenConnection) {.async.} =
  let quicConnection = state.quicConnection.getOr: return
  let disconnecting = newDisconnectingConnection(state.ids)
  quicConnection.switch(disconnecting)
  await disconnecting.drop()

{.pop.}
