import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ./closedstate

type
  DisconnectingConnection* = ref object of ConnectionState
    connection: QuicConnection
    disconnect: Future[void]
    ids: seq[ConnectionId]

proc newDisconnectingConnection*(ids: seq[ConnectionId]):
                                            DisconnectingConnection =
  DisconnectingConnection(ids: ids)

proc callDisconnect(connection: QuicConnection) {.async.} =
  if connection.disconnect != nil:
    await connection.disconnect()

{.push locks: "unknown".}

method ids*(state: DisconnectingConnection): seq[ConnectionId] =
  state.ids

method enter(state: DisconnectingConnection, connection: QuicConnection) =
  state.connection = connection
  state.disconnect = callDisconnect(connection)

method leave(state: DisconnectingConnection) =
  state.connection = nil

method send(state: DisconnectingConnection) =
  raise newException(ClosedConnectionError, "connection is disconnecting")

method receive(state: DisconnectingConnection, datagram: Datagram) =
  discard

method openStream(state: DisconnectingConnection): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is disconnecting")

method close(state: DisconnectingConnection) {.async.} =
  await state.disconnect
  state.connection.switch(newClosedConnection())

method drop(state: DisconnectingConnection) {.async.} =
  await state.disconnect
  state.connection.switch(newClosedConnection())

{.pop.}