import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream

type
  ClosedConnection* = ref object of ConnectionState
  ClosedConnectionError* = object of ConnectionError

proc newClosedConnection*: ClosedConnection =
  ClosedConnection()

{.push locks: "unknown".}

method enter(state: ClosedConnection, connection: QuicConnection) =
  connection.closed.fire()

method ids(state: ClosedConnection): seq[ConnectionId] =
  @[]

method send(state: ClosedConnection) =
  raise newException(ClosedConnectionError, "connection is closed")

method receive(state: ClosedConnection, datagram: Datagram) =
  raise newException(ClosedConnectionError, "connection is closed")

method openStream(state: ClosedConnection): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is closed")

method close(state: ClosedConnection) {.async.} =
  discard

method drop(state: ClosedConnection) {.async.} =
  discard

{.pop.}
