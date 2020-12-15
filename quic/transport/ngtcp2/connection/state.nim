from ../../quicconnection import ConnectionState
import ../../connectionid

template newConnectionState*[T: ConnectionState]: T =
  var state = T()
  state.ids = proc(): seq[ConnectionId] =
    ids(state)
  state.send = proc(connection: QuicConnection) =
    send(connection, state)
  state.receive = proc(connection: QuicConnection, datagram: Datagram) =
    receive(connection, state, datagram)
  state.openStream = proc(connection: QuicConnection): Future[Stream] =
    openStream(connection, state)
  state.drop = proc(connection: QuicConnection) =
    drop(connection, state)
  state.destroy = proc() =
    destroy(state)
  state
