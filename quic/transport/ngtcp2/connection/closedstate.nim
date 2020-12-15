import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream

type
  ClosedConnection* = ref object of ConnectionState
  ClosedConnectionError* = object of ConnectionError

method ids(state: ClosedConnection): seq[ConnectionId] =
  @[]

method send(state: ClosedConnection, connection: QuicConnection) =
  raise newException(ClosedConnectionError, "connection is closed")

method receive(state: ClosedConnection,
               connection: QuicConnection, datagram: Datagram) =
  raise newException(ClosedConnectionError, "connection is closed")

method openStream(state: ClosedConnection,
                  connection: QuicConnection): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is closed")

method drop(state: ClosedConnection, connection: QuicConnection) =
  discard

method destroy(state: ClosedConnection) =
  discard

proc newClosedConnection*: ClosedConnection =
  ClosedConnection()
