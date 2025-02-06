import ../basics
import ./tlsbackend
import ./quicconnection
import ./ngtcp2/connection/openstate

proc newQuicClientConnection*(
    tlsBackend: TLSBackend, local, remote: TransportAddress
): QuicConnection =
  let openConn = openClientConnection(tlsBackend, local, remote)
  newQuicConnection(openConn)

proc newQuicServerConnection*(
    tlsBackend: TLSBackend, local, remote: TransportAddress, datagram: Datagram
): QuicConnection =
  let openConn = openServerConnection(tlsBackend, local, remote, datagram)
  newQuicConnection(openConn)
