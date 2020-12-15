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
    ids*: proc(): seq[ConnectionId] {.gcsafe.}
    send*: proc(connection: QuicConnection) {.gcsafe.}
    receive*: proc(connection: QuicConnection, datagram: Datagram) {.gcsafe.}
    openStream*: proc(connection: QuicConnection): Future[Stream] {.gcsafe.}
    destroy*: proc () {.gcsafe.}
  IdCallback* = proc(id: ConnectionId)

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

proc destroy*(connection: QuicConnection) =
  connection.state.destroy()

proc ids*(connection: QuicConnection): seq[ConnectionId] =
  connection.state.ids()

proc `onNewId=`*(connection: QuicConnection, callback: IdCallback) =
  connection.onNewId = callback

proc `onRemoveId=`*(connection: QuicConnection, callback: IdCallback) =
  connection.onRemoveId = callback

proc send*(connection: QuicConnection) =
  connection.state.send(connection)

proc receive*(connection: QuicConnection, datagram: Datagram) =
  connection.state.receive(connection, datagram)

proc openStream*(connection: QuicConnection): Future[Stream] =
  connection.state.openStream(connection)

proc incomingStream*(connection: QuicConnection): Future[Stream] =
  connection.incoming.get()
