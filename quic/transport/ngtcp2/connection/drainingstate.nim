import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../../timeout
import ./closedstate

type
  DrainingConnection* = ref object of ConnectionState
    connection: QuicConnection
    finalDatagram: Datagram
    timeout: Timeout
    duration: Duration
    done: AsyncEvent

proc newDrainingConnection*(finalDatagram: Datagram,
                            duration: Duration): DrainingConnection =
  DrainingConnection(
    finalDatagram: finalDatagram,
    duration: duration,
    done: newAsyncEvent()
  )

proc onTimeout(state: DrainingConnection) =
  state.done.fire()

method enter(state: DrainingConnection, connection: QuicConnection) =
  state.connection = connection
  state.timeout = newTimeout(proc = state.onTimeout())
  state.timeout.set(state.duration)

method leave(state: DrainingConnection) =
  state.timeout.stop()
  state.connection = nil

method ids(state: DrainingConnection): seq[ConnectionId] =
  @[]

method send(state: DrainingConnection) =
  raise newException(ClosedConnectionError, "connection is closing")

method receive(state: DrainingConnection, datagram: Datagram) =
  state.connection.outgoing.putNoWait(state.finalDatagram)

method openStream(state: DrainingConnection): Future[Stream] {.async.} =
  raise newException(ClosedConnectionError, "connection is closing")

method drain(state: DrainingConnection) {.async.} =
  await state.done.wait()

method drop(state: DrainingConnection) =
  state.connection.switch(newClosedConnection())
