import pkg/chronos
import ../udp/datagram
import ./quicconnection
import ./stream
import ./ngtcp2
import ./ngtcp2/connection/openstate

proc newConnection(ngtcp2Connection: Ngtcp2Connection): QuicConnection =
  let state = newOpenConnection(ngtcp2Connection)
  let connection = newQuicConnection(state)
  ngtcp2Connection.onSend = proc(datagram: Datagram) =
    connection.outgoing.putNoWait(datagram)
  ngtcp2Connection.onIncomingStream = proc(stream: Stream) =
    connection.incoming.putNoWait(stream)
  ngtcp2Connection.onHandshakeDone = proc =
    connection.handshake.fire()
  connection

proc newQuicClientConnection*(local, remote: TransportAddress): QuicConnection =
  newConnection(newNgtcp2Client(local, remote))

proc newQuicServerConnection*(local, remote: TransportAddress,
                              datagram: Datagram): QuicConnection =
  newConnection(newNgtcp2Server(local, remote, datagram.data))
