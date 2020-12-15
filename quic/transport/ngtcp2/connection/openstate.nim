import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../connection
import ../streams
import ./state
import ./closedstate

type
  OpenConnection* = ref object of ConnectionState
    connection: Ngtcp2Connection

proc ids(state: OpenConnection): seq[ConnectionId] =
  state.connection.ids

proc send(connection: QuicConnection, state: OpenConnection) =
  state.connection.send()

proc receive(connection: QuicConnection,
             state: OpenConnection, datagram: Datagram) =
  state.connection.receive(datagram)

proc openStream(connection: QuicConnection,
                state: OpenConnection): Future[Stream] {.async.} =
  await connection.handshake.wait()
  result = state.connection.openStream()

proc drop(connection: QuicConnection, state: OpenConnection) =
  connection.switch(newClosedConnection())

proc destroy(state: OpenConnection) =
  discard

proc newOpenConnection*(connection: Ngtcp2Connection): OpenConnection =
  var state = newConnectionState[OpenConnection]()
  state.connection = connection
  state
