import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../connection
import ../streams
import ./closedstate

type
  OpenConnection* = ref object of ConnectionState
    connection: Ngtcp2Connection

method ids(state: OpenConnection): seq[ConnectionId] =
  state.connection.ids

method send(state: OpenConnection, connection: QuicConnection) =
  state.connection.send()

method receive(state: OpenConnection,
               connection: QuicConnection, datagram: Datagram) =
  state.connection.receive(datagram)

method openStream(state: OpenConnection,
                  connection: QuicConnection): Future[Stream] {.async.} =
  await connection.handshake.wait()
  result = state.connection.openStream()

method drop(state: OpenConnection, connection: QuicConnection) =
  connection.switch(newClosedConnection())

method destroy(state: OpenConnection) =
  discard

proc newOpenConnection*(connection: Ngtcp2Connection): OpenConnection =
  OpenConnection(connection: connection)
