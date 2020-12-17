import pkg/chronos
import ../../../udp/datagram
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

{.push locks: "unknown".}

method receive(state: ClosingConnection, datagram: Datagram) =
  state.connection.outgoing.putNoWait(state.finalDatagram)

{.pop.}
