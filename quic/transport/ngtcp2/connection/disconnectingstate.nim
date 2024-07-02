import chronicles

import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream
import ./closedstate

logScope:
  topics = "quic disconnectingstate"

type
  DisconnectingConnection* = ref object of ConnectionState
    connection: Opt[QuicConnection]
    disconnect: Future[void]
    ids: seq[ConnectionId]

proc newDisconnectingConnection*(ids: seq[ConnectionId]):
                                            DisconnectingConnection =
  DisconnectingConnection(ids: ids)

proc callDisconnect(connection: QuicConnection) {.async.} =
  let disconnect = connection.disconnect.valueOr: return
  trace "Calling disconnect proc on QuicConnection"
  await disconnect()
  trace "Called disconnect proc on QuicConnection"

{.push locks: "unknown".}

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

method openStream(state: DisconnectingConnection,
                  unidirectional: bool): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is disconnecting")

method close(state: DisconnectingConnection) {.async.} =
  await state.disconnect
  let connection = state.connection.valueOr: return
  connection.switch(newClosedConnection())

method drop(state: DisconnectingConnection) {.async.} =
  trace "Dropping DisconnectingConnection state"
  trace "Awaiting quic disconnecton"
  await state.disconnect
  trace "Quic disconnecton finished"
  let connection = state.connection.valueOr: return
  connection.switch(newClosedConnection())
  trace "dropped DisconnectingConnection state"

{.pop.}
