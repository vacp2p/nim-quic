import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../../timeout
import ./closedstate

type
  ClosingConnection* = ref object of ConnectionState
    connection: QuicConnection
    finalDatagram: Datagram
    ids: seq[ConnectionId]
    timeout: Timeout
    duration: Duration
    done: AsyncEvent

proc newClosingConnection*(finalDatagram: Datagram, ids: seq[ConnectionId],
                           duration: Duration): ClosingConnection =
  ClosingConnection(
    finalDatagram: finalDatagram,
    ids: ids,
    duration: duration,
    done: newAsyncEvent()
  )

proc onTimeout(state: ClosingConnection) =
  state.done.fire()

{.push locks: "unknown".}

method enter(state: ClosingConnection, connection: QuicConnection) =
  state.connection = connection
  state.timeout = newTimeout(proc = state.onTimeout())
  state.timeout.set(state.duration)

method leave(state: ClosingConnection) =
  state.timeout.stop()
  state.connection = nil

method ids(state: ClosingConnection): seq[ConnectionId] =
  state.ids

method send(state: ClosingConnection) =
  raise newException(ClosedConnectionError, "connection is closing")

method receive(state: ClosingConnection, datagram: Datagram) =
  state.connection.outgoing.putNoWait(state.finalDatagram)

method openStream(state: ClosingConnection): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is closing")

method close(state: ClosingConnection) {.async.} =
  await state.done.wait()

method drop(state: ClosingConnection) =
  state.connection.switch(newClosedConnection())

{.pop.}
