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

method ids*(state: ConnectionState): seq[ConnectionId] {.base.} =
  doAssert false # override this method

method send*(state: ConnectionState, connection: QuicConnection) {.base.} =
  doAssert false # override this method

method receive*(state: ConnectionState,
                connection: QuicConnection, datagram: Datagram) {.base.} =
  doAssert false # override this method

method openStream*(state: ConnectionState,
                   connection: QuicConnection): Future[Stream] {.base.} =
  doAssert false # override this method

method drop*(state: ConnectionState, connection: QuicConnection) {.base.} =
  doAssert false # override this method

method destroy*(state: ConnectionState) {.base.} =
  doAssert false # override this method

proc newQuicConnection*(state: ConnectionState): QuicConnection =
  QuicConnection(
    state: state,
    outgoing: newAsyncQueue[Datagram](),
    handshake: newAsyncEvent(),
    incoming: newAsyncQueue[Stream]()
  )

proc switch*(connection: QuicConnection, newState: ConnectionState) =
  connection.state.destroy()
  connection.state = newState

proc `onNewId=`*(connection: QuicConnection, callback: IdCallback) =
  connection.onNewId = callback

proc `onRemoveId=`*(connection: QuicConnection, callback: IdCallback) =
  connection.onRemoveId = callback

proc ids*(connection: QuicConnection): seq[ConnectionId] =
  connection.state.ids()

proc send*(connection: QuicConnection) =
  connection.state.send(connection)

proc receive*(connection: QuicConnection, datagram: Datagram) =
  connection.state.receive(connection, datagram)

proc openStream*(connection: QuicConnection): Future[Stream] =
  connection.state.openStream(connection)

proc incomingStream*(connection: QuicConnection): Future[Stream] =
  connection.incoming.get()

proc drop*(connection: QuicConnection) =
  connection.state.drop(connection)
