import results
import ../basics
import ./tlsbackend
import ./quicconnection
import ./ngtcp2/connection/openstate

proc newQuicClientConnection*(tlsBackend: TLSBackend, local, remote: TransportAddress): Result[QuicConnection, string] =
  let openConn = ?openClientConnection(tlsBackend, local, remote)
  ok(newQuicConnection(openConn))

proc newQuicServerConnection*(tlsBackend: TLSBackend, local, remote: TransportAddress,
                              datagram: Datagram): Result[QuicConnection, string] =
  let openConn = ?openServerConnection(tlsBackend, local, remote, datagram)
  ok(newQuicConnection(openConn))
