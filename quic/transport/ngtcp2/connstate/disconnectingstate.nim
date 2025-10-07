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
  disconnect: Future[void]
  ids: seq[ConnectionId]

proc newDisconnectingConnection*(
    ids: seq[ConnectionId], certificates: seq[seq[byte]]
): DisconnectingConnection =
  DisconnectingConnection(ids: ids, derCertificates: certificates)

proc callDisconnect(connection: QuicConnection) {.async.} =
  let disconnect = connection.disconnect.valueOr:
    return
  trace "Calling disconnect proc on QuicConnection"
  await disconnect()
  trace "Called disconnect proc on QuicConnection"

method ids*(state: DisconnectingConnection): seq[ConnectionId] =
  state.ids

method enter(
    state: DisconnectingConnection, connection: QuicConnection
) {.raises: [QuicError].} =
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

method send(state: DisconnectingConnection) {.raises: [QuicError].} =
  raise newException(ClosedConnectionError, "connection is disconnecting")

method receive(state: DisconnectingConnection, datagram: sink Datagram) =
  discard

method openStream(
    state: DisconnectingConnection, unidirectional: bool
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  raise newException(ClosedConnectionError, "connection is disconnecting")

template handleWithQuicError*(body: untyped) =
  try:
    body
  except CancelledError as e:
    raise e
  except QuicError as e:
    raise e
  except CatchableError as e:
    raise newException(QuicError, e.msg)

method close(
    state: DisconnectingConnection
) {.async: (raises: [CancelledError, QuicError]).} =
  handleWithQuicError:
    await state.disconnect
  let connection = state.connection.valueOr:
    return
  connection.switch(newClosedConnection(state.derCertificates))

method drop(
    state: DisconnectingConnection
) {.async: (raises: [CancelledError, QuicError]).} =
  trace "Drop DisconnectingConnection state"
  handleWithQuicError:
    await state.disconnect
  let connection = state.connection.valueOr:
    return
  connection.switch(newClosedConnection(state.derCertificates))
