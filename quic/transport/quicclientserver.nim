import pkg/chronos
import ../udp/datagram
import ./quicconnection
import ./ngtcp2/native
import ./ngtcp2/connection/openstate

proc newConnection(ngtcp2Connection: Ngtcp2Connection): QuicConnection =
  let state = newOpenConnection(ngtcp2Connection)
  let connection = newQuicConnection(state)
  connection

proc newQuicClientConnection*(local, remote: TransportAddress): QuicConnection =
  newConnection(newNgtcp2Client(local, remote))

proc newQuicServerConnection*(local, remote: TransportAddress,
                              datagram: Datagram): QuicConnection =
  newConnection(newNgtcp2Server(local, remote, datagram.data))
