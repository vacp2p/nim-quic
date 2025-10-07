import ../../../basics
import ../../quicconnection
import ../../connectionid
import ./drainingstate

type ClosingConnection* = ref object of DrainingConnection
  finalDatagram: Datagram

proc newClosingConnection*(
    finalDatagram: Datagram,
    ids: seq[ConnectionId],
    duration: Duration,
    certificates: seq[seq[byte]],
): ClosingConnection =
  let state = ClosingConnection(finalDatagram: finalDatagram)
  state.init(ids, duration, certificates)
  state

proc sendFinalDatagram(state: ClosingConnection) =
  let connection = state.connection.valueOr:
    return
  try:
    connection.outgoing.putNoWait(state.finalDatagram)
  except AsyncQueueFullError:
    raise newException(QuicError, "Outgoing queue is full")

method enter(
    state: ClosingConnection, connection: QuicConnection
) {.raises: [QuicError].} =
  procCall enter(DrainingConnection(state), connection)
  state.sendFinalDatagram()

method receive(
    state: ClosingConnection, datagram: sink Datagram
) {.raises: [QuicError].} =
  state.sendFinalDatagram()
