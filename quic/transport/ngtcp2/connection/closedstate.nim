import chronicles

import ../../../basics
import ../../quicconnection
import ../../connectionid
import ../../stream

logScope:
  topics = "quic closedstate"

type
  ClosedConnection* = ref object of ConnectionState
  ClosedConnectionError* = object of ConnectionError

proc newClosedConnection*(certificates: seq[seq[byte]]): ClosedConnection =
  ClosedConnection(derCertificates: certificates)

method ids(state: ClosedConnection): seq[ConnectionId] =
  @[]

method send(state: ClosedConnection) =
  raise newException(ClosedConnectionError, "connection is closed")

method receive(state: ClosedConnection, datagram: sink Datagram) =
  warn "Receive ClosedConnection state"

method openStream(
    state: ClosedConnection, unidirectional: bool
): Future[Stream] {.async: (raises: [CancelledError, QuicError]).} =
  raise newException(ClosedConnectionError, "connection is closed")

method close(state: ClosedConnection) {.async.} =
  discard

method drop(state: ClosedConnection) {.async.} =
  trace "Drop ClosedConnection state"
