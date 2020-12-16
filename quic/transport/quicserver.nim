import pkg/chronos
import ../udp/datagram
import ./quicconnection
import ./ngtcp2/connection/openstate
import ./ngtcp2/server

proc newQuicServerConnection*(local, remote: TransportAddress,
                              datagram: Datagram): QuicConnection =
  let server = newNgtcp2Server(local, remote, datagram.data)
  let state = newOpenConnection(server)
  let connection = newQuicConnection(state)
  server.outgoing = connection.outgoing
  server.incoming = connection.incoming
  server.handshake = connection.handshake
  connection
