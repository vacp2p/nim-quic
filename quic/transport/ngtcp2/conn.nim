import bearssl/rand
import chronos
import ../tlsbackend
import ./native/[client, server]
import ../../basics
import ./connstate/openstate

proc openClientConnection*(
    tlsBackend: TLSBackend, local, remote: TransportAddress, rng: ref HmacDrbgContext
): OpenConnection =
  let ngtcp2Conn = newNgtcp2Client(tlsBackend.picoTLS, local, remote, rng)
  newOpenConnection(ngtcp2Conn)

proc openServerConnection*(
    tlsBackend: TLSBackend,
    local, remote: TransportAddress,
    rng: ref HmacDrbgContext,
    datagram: Datagram,
): OpenConnection =
  newOpenConnection(
    newNgtcp2Server(tlsBackend.picoTLS, local, remote, datagram.data, rng)
  )