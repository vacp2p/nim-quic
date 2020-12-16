import pkg/chronos
import ../udp/datagram
import ./connectionid
import ./stream

type
  QuicConnection* = ref object
    state: ConnectionState
    outgoing*: AsyncQueue[Datagram]
    handshake*: AsyncEvent
    incoming*: AsyncQueue[Stream]
    onNewId: IdCallback
    onRemoveId: IdCallback
  ConnectionState* = ref object of RootObj
  IdCallback* = proc(id: ConnectionId)
  ConnectionError* = object of IOError

{.push base, locks: "unknown".}

method enter*(state: ConnectionState, connection: QuicConnection) =
  discard

method leave*(state: ConnectionState) =
  discard

method ids*(state: ConnectionState): seq[ConnectionId] =
  doAssert false # override this method

method send*(state: ConnectionState) =
  doAssert false # override this method

method receive*(state: ConnectionState, datagram: Datagram) =
  doAssert false # override this method

method openStream*(state: ConnectionState): Future[Stream] =
  doAssert false # override this method

method drop*(state: ConnectionState) =
  doAssert false # override this method

method drain*(state: ConnectionState): Future[void] =
  doAssert false # override this method

{.pop.}

proc newQuicConnection*(state: ConnectionState): QuicConnection =
  let connection = QuicConnection(
    state: state,
    outgoing: newAsyncQueue[Datagram](),
    handshake: newAsyncEvent(),
    incoming: newAsyncQueue[Stream]()
  )
  state.enter(connection)
  connection

proc switch*(connection: QuicConnection, newState: ConnectionState) =
  connection.state.leave()
  connection.state = newState
  connection.state.enter(connection)

proc `onNewId=`*(connection: QuicConnection, callback: IdCallback) =
  connection.onNewId = callback

proc `onRemoveId=`*(connection: QuicConnection, callback: IdCallback) =
  connection.onRemoveId = callback

proc ids*(connection: QuicConnection): seq[ConnectionId] =
  connection.state.ids()

proc send*(connection: QuicConnection) =
  connection.state.send()

proc receive*(connection: QuicConnection, datagram: Datagram) =
  connection.state.receive(datagram)

proc openStream*(connection: QuicConnection): Future[Stream] =
  connection.state.openStream()

proc incomingStream*(connection: QuicConnection): Future[Stream] =
  connection.incoming.get()

proc drain*(connection: QuicConnection): Future[void] =
  connection.state.drain()

proc drop*(connection: QuicConnection) =
  connection.state.drop()
