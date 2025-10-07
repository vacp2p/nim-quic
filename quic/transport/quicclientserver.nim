import ../basics
import ./tlsbackend
import ./quicconnection
import ./ngtcp2/conn
import bearssl/rand

proc newQuicClientConnection*(
    tlsBackend: TLSBackend, local, remote: TransportAddress, rng: ref HmacDrbgContext
): QuicConnection =
  let openConn = openClientConnection(tlsBackend, local, remote, rng)
  newQuicConnection(openConn)

proc newQuicServerConnection*(
    tlsBackend: TLSBackend,
    local, remote: TransportAddress,
    datagram: Datagram,
    rng: ref HmacDrbgContext,
): QuicConnection =
  let openConn = openServerConnection(tlsBackend, local, remote, rng, datagram)
  newQuicConnection(openConn)
