import ../basics
import ./connectionid
import ./stream

type
  QuicConnection* = ref object
    state: ConnectionState
    outgoing*: AsyncQueue[Datagram]
    incoming*: AsyncQueue[Stream]
    handshake*: AsyncEvent
    disconnect*: Option[proc(): Future[void] {.gcsafe, upraises: [].}]
    onNewId*: IdCallback
    onRemoveId*: IdCallback
  ConnectionState* = ref object of RootObj
    entered: bool
  IdCallback* = proc(id: ConnectionId) {.gcsafe, upraises: [].}
  ConnectionError* = object of QuicError

push: {.base, locks: "unknown", upraises: [QuicError].}

method enter*(state: ConnectionState, connection: QuicConnection) =
  doAssert not state.entered # states are not reentrant
  state.entered = true

method leave*(state: ConnectionState) =
  discard

method ids*(state: ConnectionState): seq[ConnectionId] {.upraises: [].} =
  doAssert false # override this method

method send*(state: ConnectionState) =
  doAssert false # override this method

method receive*(state: ConnectionState, datagram: Datagram) =
  doAssert false # override this method

method openStream*(state: ConnectionState,
                   unidirectional: bool): Future[Stream] =
  doAssert false # override this method

method drop*(state: ConnectionState): Future[void] =
  doAssert false # override this method

method close*(state: ConnectionState): Future[void] =
  doAssert false # override this method

{.pop.}

proc newQuicConnection*(state: ConnectionState): QuicConnection =
  let connection = QuicConnection(
    state: state,
    outgoing: newAsyncQueue[Datagram](),
    incoming: newAsyncQueue[Stream](),
    handshake: newAsyncEvent(),
  )
  state.enter(connection)
  connection

proc switch*(connection: QuicConnection, newState: ConnectionState) =
  connection.state.leave()
  connection.state = newState
  connection.state.enter(connection)

proc ids*(connection: QuicConnection): seq[ConnectionId] =
  connection.state.ids()

proc send*(connection: QuicConnection) =
  connection.state.send()

proc receive*(connection: QuicConnection, datagram: Datagram) =
  connection.state.receive(datagram)

proc openStream*(connection: QuicConnection,
                 unidirectional = false): Future[Stream] =
  connection.state.openStream(unidirectional = unidirectional)

proc incomingStream*(connection: QuicConnection): Future[Stream] =
  connection.incoming.get()

proc close*(connection: QuicConnection): Future[void] =
  connection.state.close()

proc drop*(connection: QuicConnection): Future[void] =
  connection.state.drop()
