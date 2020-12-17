import pkg/chronos
import ../udp/datagram
import ./quicconnection
import ./ngtcp2/connection/openstate
import ./ngtcp2/server

proc onSend(connection: QuicConnection, datagram: Datagram) =
  connection.outgoing.putNoWait(datagram)

proc newQuicServerConnection*(local, remote: TransportAddress,
                              datagram: Datagram): QuicConnection =
  let server = newNgtcp2Server(local, remote, datagram.data)
  let state = newOpenConnection(server)
  let connection = newQuicConnection(state)
  server.onSend = proc (datagram: Datagram) = connection.onSend(datagram)
  server.incoming = connection.incoming
  server.handshake = connection.handshake
  connection
