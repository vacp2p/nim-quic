import chronicles

import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream
import ./closedstate

logScope:
  topics = "quic disconnectingstate"

type DisconnectingConnection* = ref object of ConnectionState
  connection: Opt[QuicConnection]
  disconnect: Future[void].Raising([])
  ids: seq[ConnectionId]

proc newDisconnectingConnection*(ids: seq[ConnectionId]): DisconnectingConnection =
  DisconnectingConnection(ids: ids)

proc callDisconnect(connection: QuicConnection): Future[void] {.async: (raises: []).} =
  let disconnect = connection.disconnect.valueOr:
    return
  trace "Calling disconnect proc on QuicConnection"
  try:
    await disconnect()
  except CatchableError as exc:
    trace "could not call disconnect", err = exc.msg
  trace "Called disconnect proc on QuicConnection"

method ids*(state: DisconnectingConnection): seq[ConnectionId] =
  state.ids

method enter(state: DisconnectingConnection, connection: QuicConnection) =
  trace "Entering DisconnectingConnection state"
  procCall enter(ConnectionState(state), connection)
  state.connection = Opt.some(connection)
  state.disconnect = callDisconnect(connection)
  trace "Entered DisconnectingConnection state"

method leave(state: DisconnectingConnection) =
  trace "Leaving DisconnectingConnection state"
  procCall leave(ConnectionState(state))
  state.connection = Opt.none(QuicConnection)
  trace "Left DisconnectingConnection state"

method send(state: DisconnectingConnection) =
  raise newException(ClosedConnectionError, "connection is disconnecting")

method receive(state: DisconnectingConnection, datagram: Datagram) =
  discard

method openStream(
    state: DisconnectingConnection, unidirectional: bool
): Future[Stream] {.async: (raises: [CancelledError, ConnectionError, QuicError]).} =
  raise newException(ClosedConnectionError, "connection is disconnecting")

method close(state: DisconnectingConnection) {.async: (raises: [QuicError]).} =
  await state.disconnect
  let connection = state.connection.valueOr:
    return
  connection.switch(newClosedConnection())

method drop(state: DisconnectingConnection) {.async.} =
  trace "Dropping DisconnectingConnection state"
  trace "Awaiting quic disconnecton"
  await state.disconnect
  trace "Quic disconnecton finished"
  let connection = state.connection.valueOr:
    return
  connection.switch(newClosedConnection())
  trace "dropped DisconnectingConnection state"
