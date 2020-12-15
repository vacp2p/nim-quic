import pkg/chronos
import ./quicconnection
import ./ngtcp2/connection/openstate
import ./ngtcp2/server

proc newQuicServerConnection*(local, remote: TransportAddress,
                              datagram: openArray[byte]): QuicConnection =
  let server = newNgtcp2Server(local, remote, datagram)
  let state = newOpenConnection(server)
  let connection = newQuicConnection(state)
  server.outgoing = connection.outgoing
  server.incoming = connection.incoming
  server.handshake = connection.handshake
  connection
