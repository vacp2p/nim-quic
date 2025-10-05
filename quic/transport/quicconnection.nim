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
    disconnect*: Opt[proc(): Future[void] {.gcsafe, raises: [].}]
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
  doAssert not state.entered # states are not reentrant
  state.entered = true

method leave*(state: ConnectionState) {.base, raises: [QuicError].} =
  discard

method ids*(state: ConnectionState): seq[ConnectionId] {.base, raises: [].} =
  doAssert false # override this method

method send*(state: ConnectionState) {.base, raises: [QuicError].} =
  doAssert false # override this method

method receive*(
    state: ConnectionState, datagram: sink Datagram
) {.base, raises: [QuicError].} =
  doAssert false # override this method

method openStream*(
    state: ConnectionState, unidirectional: bool
): Future[Stream] {.base, async: (raises: [CancelledError, QuicError]).} =
  doAssert false # override this method

method drop*(
    state: ConnectionState
): Future[void] {.base, gcsafe, raises: [QuicError].} =
  doAssert false # override this method

method close*(
    state: ConnectionState
): Future[void] {.base, gcsafe, raises: [QuicError].} =
  doAssert false # override this method

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
  trace "Switched quic connection state"

proc ids*(connection: QuicConnection): seq[ConnectionId] =
  connection.state.ids()

proc send*(connection: QuicConnection) =
  connection.state.send()

proc receive*(connection: QuicConnection, datagram: sink Datagram) =
  connection.state.receive(datagram)

proc openStream*(
    connection: QuicConnection, unidirectional = false
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  await connection.state.openStream(unidirectional = unidirectional)

proc incomingStream*(
    connection: QuicConnection
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  await connection.incoming.get()

proc close*(connection: QuicConnection): Future[void] =
  connection.state.close()

proc drop*(connection: QuicConnection): Future[void] {.async.} =
  trace "Dropping quic connection"
  await connection.state.drop()
  trace "Drop quic connection done"

proc certificates*(connection: QuicConnection): seq[seq[byte]] {.raises: [].} =
  connection.state.certificates()
