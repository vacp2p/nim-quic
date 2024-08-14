import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../../timeout
import ./disconnectingstate
import ./closedstate

type
  DrainingConnection* = ref object of ConnectionState
    connection*: Opt[QuicConnection]
    ids: seq[ConnectionId]
    timeout: Timeout
    duration: Duration
    done: AsyncEvent

proc init*(state: DrainingConnection,
           ids: seq[ConnectionId], duration: Duration) =
  state.ids = ids
  state.duration = duration
  state.done = newAsyncEvent()

proc newDrainingConnection*(ids: seq[ConnectionId],
                            duration: Duration): DrainingConnection =
  let state = DrainingConnection()
  state.init(ids, duration)
  state

proc onTimeout(state: DrainingConnection) {.raises: [].} =
  state.done.fire()

{.push locks: "unknown", raises: [QuicError].}

method enter*(state: DrainingConnection, connection: QuicConnection) =
  procCall enter(ConnectionState(state), connection)
  state.connection = Opt.some(connection)
  state.timeout = newTimeout(proc {.raises: [].} = state.onTimeout())
  state.timeout.set(state.duration)

method leave(state: DrainingConnection) =
  procCall leave(ConnectionState(state))
  state.timeout.stop()
  state.connection = Opt.none(QuicConnection)

method ids(state: DrainingConnection): seq[ConnectionId] {.raises: [].} =
  state.ids

method send(state: DrainingConnection) =
  raise newException(ClosedConnectionError, "connection is closing")

method receive(state: DrainingConnection, datagram: Datagram) =
  discard

method openStream(state: DrainingConnection,
                  unidirectional: bool): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is closing")

method close(state: DrainingConnection) {.async.} =
  await state.done.wait()
  let connection = state.connection.valueOr: return
  let disconnecting = newDisconnectingConnection(state.ids)
  connection.switch(disconnecting)
  await disconnecting.close()

method drop(state: DrainingConnection) {.async.} =
  let connection = state.connection.valueOr: return
  let disconnecting = newDisconnectingConnection(state.ids)
  connection.switch(disconnecting)
  await disconnecting.drop()

{.pop.}
