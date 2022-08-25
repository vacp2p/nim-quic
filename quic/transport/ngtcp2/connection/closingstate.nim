import ../../../basics
import ../../quicconnection
import ../../connectionid
import ./drainingstate

type
  ClosingConnection* = ref object of DrainingConnection
    finalDatagram: Datagram

proc newClosingConnection*(finalDatagram: Datagram, ids: seq[ConnectionId],
                           duration: Duration): ClosingConnection =
  let state = ClosingConnection(finalDatagram: finalDatagram)
  state.init(ids, duration)
  state

proc sendFinalDatagram(state: ClosingConnection) =
  let connection = state.connection.getOr: return
  try:
    connection.outgoing.putNoWait(state.finalDatagram)
  except AsyncQueueFullError:
    raise newException(QuicError, "Outgoing queue is full")

{.push locks: "unknown".}

method enter(state: ClosingConnection, connection: QuicConnection) =
  procCall enter(DrainingConnection(state), connection)
  state.sendFinalDatagram()

method receive(state: ClosingConnection, datagram: Datagram) =
  state.sendFinalDatagram()

{.pop.}
