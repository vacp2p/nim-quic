import pkg/chronos
import ./quicconnection
import ./ngtcp2/connection/openstate
import ./ngtcp2/client

proc newQuicClientConnection*(local, remote: TransportAddress): QuicConnection =
  let client = newNgtcp2Client(local, remote)
  let state = newOpenConnection(client)
  let connection = newQuicConnection(state)
  client.outgoing = connection.outgoing
  client.incoming = connection.incoming
  client.handshake = connection.handshake
  connection
