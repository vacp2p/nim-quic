import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../../timeout
import ./closedstate

type
  DrainingConnection* = ref object of ConnectionState
    connection*: QuicConnection
    ids: seq[ConnectionId]
    timeout: Timeout
    duration: Duration
    done: AsyncEvent

proc init*(state: DrainingConnection,
           ids: seq[ConnectionId], duration: Duration) =
  state.ids = ids
  state.duration = duration
  state.done = newAsyncEvent()

proc newDrainingConnection*(ids: seq[ConnectionId],
                            duration: Duration): DrainingConnection =
  let state = DrainingConnection()
  state.init(ids, duration)
  state

proc onTimeout(state: DrainingConnection) =
  state.done.fire()

{.push locks: "unknown".}

method enter(state: DrainingConnection, connection: QuicConnection) =
  state.connection = connection
  state.timeout = newTimeout(proc = state.onTimeout())
  state.timeout.set(state.duration)

method leave(state: DrainingConnection) =
  state.timeout.stop()
  state.connection = nil

method ids(state: DrainingConnection): seq[ConnectionId] =
  state.ids

method send(state: DrainingConnection) =
  raise newException(ClosedConnectionError, "connection is closing")

method receive(state: DrainingConnection, datagram: Datagram) =
  discard

method openStream(state: DrainingConnection): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is closing")

method close(state: DrainingConnection) {.async.} =
  await state.done.wait()

method drop(state: DrainingConnection) =
  state.connection.switch(newClosedConnection())

{.pop.}
