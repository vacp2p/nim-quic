import ../basics
import ./quicconnection
import ./ngtcp2/connection/openstate

proc newQuicClientConnection*(local, remote: TransportAddress): QuicConnection =
  newQuicConnection(openClientConnection(local, remote))

proc newQuicServerConnection*(local, remote: TransportAddress,
                              datagram: Datagram): QuicConnection =
  newQuicConnection(openServerConnection(local, remote, datagram))
