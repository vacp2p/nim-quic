import pkg/chronicles
import ../basics
import ./connectionid
import ./stream

logScope:
  topics = "quic quicconnection"

type
  QuicConnection* = ref object
    state: ConnectionState
    outgoing*: AsyncQueue[Datagram]
    incoming*: AsyncQueue[Stream]
    handshake*: AsyncEvent
    timeout*: AsyncEvent
    error*: AsyncEventQueue[string]
    disconnect*: Opt[proc(): Future[void] {.gcsafe, async: (raises: [CancelledError]).}]
    onNewId*: IdCallback
    onRemoveId*: IdCallback

  ConnectionState* = ref object of RootObj
    entered: bool
    derCertificates*: seq[seq[byte]]

  IdCallback* = proc(id: ConnectionId) {.gcsafe, raises: [].}
  ConnectionError* = object of QuicError

method enter*(
    state: ConnectionState, connection: QuicConnection
) {.base, raises: [QuicError].} =
  doAssert not state.entered, "states are not reentrant"
  state.entered = true

method leave*(state: ConnectionState) {.base, raises: [QuicError].} =
  discard

method ids*(state: ConnectionState): seq[ConnectionId] {.base, raises: [].} =
  raiseAssert "must override method: ids"

method send*(state: ConnectionState) {.base, raises: [QuicError].} =
  raiseAssert "must override method: send"

method receive*(
    state: ConnectionState, datagram: sink Datagram
) {.base, raises: [QuicError].} =
  raiseAssert "must override method: receive"

method openStream*(
    state: ConnectionState, unidirectional: bool
): Future[Stream] {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "must override method: openStream"

method drop*(
    state: ConnectionState
): Future[void] {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "must override method: drop"

method close*(
    state: ConnectionState
): Future[void] {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "must override method: close"

proc certificates*(state: ConnectionState): seq[seq[byte]] {.raises: [].} =
  state.derCertificates

proc newQuicConnection*(state: ConnectionState): QuicConnection =
  let connection = QuicConnection(
    state: state,
    outgoing: newAsyncQueue[Datagram](),
    incoming: newAsyncQueue[Stream](),
    handshake: newAsyncEvent(),
    timeout: newAsyncEvent(),
    error: newAsyncEventQueue[string](1),
  )
  state.enter(connection)
  connection

proc switch*(connection: QuicConnection, newState: ConnectionState) =
  trace "Switching quic connection state"
  connection.state.leave()
  connection.state = newState
  connection.state.enter(connection)

proc ids*(connection: QuicConnection): seq[ConnectionId] =
  connection.state.ids()

proc send*(connection: QuicConnection) =
  connection.state.send()

proc receive*(connection: QuicConnection, datagram: sink Datagram) =
  connection.state.receive(datagram)

proc openStream*(
    connection: QuicConnection, unidirectional = false
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  await connection.state.openStream(unidirectional)

proc incomingStream*(
    connection: QuicConnection
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  await connection.incoming.get()

proc close*(
    connection: QuicConnection
): Future[void] {.async: (raises: [CancelledError, QuicError]).} =
  await connection.state.close()

proc drop*(
    connection: QuicConnection
): Future[void] {.async: (raises: [CancelledError, QuicError]).} =
  trace "Dropping quic connection"
  await connection.state.drop()

proc certificates*(connection: QuicConnection): seq[seq[byte]] {.raises: [].} =
  connection.state.certificates()
