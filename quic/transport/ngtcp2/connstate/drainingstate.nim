import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../../timeout
import ./disconnectingstate
import ./closedstate

type DrainingConnection* = ref object of ConnectionState
  connection*: Opt[QuicConnection]
  ids: seq[ConnectionId]
  timeout: Timeout
  duration: Duration
  done: AsyncEvent

proc init*(
    state: DrainingConnection,
    ids: seq[ConnectionId],
    duration: Duration,
    certificates: seq[seq[byte]],
) =
  state.ids = ids
  state.duration = duration
  state.derCertificates = certificates
  state.done = newAsyncEvent()

proc newDrainingConnection*(
    ids: seq[ConnectionId], duration: Duration, certificates: seq[seq[byte]]
): DrainingConnection =
  let state = DrainingConnection()
  state.init(ids, duration, certificates)
  state

method enter*(
    state: DrainingConnection, connection: QuicConnection
) {.raises: [QuicError].} =
  procCall enter(ConnectionState(state), connection)
  state.connection = Opt.some(connection)
  state.timeout = newTimeout(
    proc() {.raises: [].} =
      state.done.fire()
  )
  state.timeout.set(state.duration)

method leave(state: DrainingConnection) =
  procCall leave(ConnectionState(state))
  state.timeout.stop()
  state.connection = Opt.none(QuicConnection)
  state.done.fire()

method ids(state: DrainingConnection): seq[ConnectionId] {.raises: [].} =
  state.ids

method send(state: DrainingConnection) {.raises: [QuicError].} =
  raise newException(ClosedConnectionError, "connection is closing")

method receive(state: DrainingConnection, datagram: sink Datagram) =
  discard

method openStream(
    state: DrainingConnection, unidirectional: bool
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  raise newException(ClosedConnectionError, "connection is closing")

method close(
    state: DrainingConnection
) {.async: (raises: [CancelledError, QuicError]).} =
  await state.done.wait()
  let connection = state.connection.valueOr:
    return
  let disconnecting = newDisconnectingConnection(state.ids, state.derCertificates)
  connection.switch(disconnecting)
  await disconnecting.close()

method drop(
    state: DrainingConnection
) {.async: (raises: [CancelledError, QuicError]).} =
  let connection = state.connection.valueOr:
    return
  let disconnecting = newDisconnectingConnection(state.ids, state.derCertificates)
  connection.switch(disconnecting)
  await disconnecting.drop()
