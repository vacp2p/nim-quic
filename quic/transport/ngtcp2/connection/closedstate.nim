import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ./state

type
  ClosedConnection* = ref object of ConnectionState
  ClosedConnectionError* = object of ConnectionError

proc ids(state: ClosedConnection): seq[ConnectionId] =
  @[]

proc send(connection: QuicConnection, state: ClosedConnection) =
  raise newException(ClosedConnectionError, "connection is closed")

proc receive(connection: QuicConnection,
             state: ClosedConnection, datagram: Datagram) =
  raise newException(ClosedConnectionError, "connection is closed")

proc openStream(connection: QuicConnection,
                state: ClosedConnection): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is closed")

proc drop(connection: QuicConnection, state: ClosedConnection) =
  discard

proc destroy(state: ClosedConnection) =
  discard

proc newClosedConnection*: ClosedConnection =
  newConnectionState[ClosedConnection]()
