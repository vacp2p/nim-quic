import bearssl/rand
import chronos
import ../tlsbackend
import ./native/[client, server]
import ../../basics
import ./connstate/openstate

proc openClientConnection*(
    tlsBackend: TLSBackend, local, remote: TransportAddress, rng: ref HmacDrbgContext
): OpenConnection =
  newOpenConnection(newNgtcp2Client(tlsBackend.ctx, local, remote, rng))

proc openServerConnection*(
    tlsBackend: TLSBackend,
    local, remote: TransportAddress,
    rng: ref HmacDrbgContext,
    datagram: Datagram,
): OpenConnection =
  newOpenConnection(newNgtcp2Server(tlsBackend.ctx, local, remote, datagram.data, rng))
