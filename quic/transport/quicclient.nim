import pkg/chronos
import ../udp/datagram
import ./quicconnection
import ./ngtcp2/connection/openstate
import ./ngtcp2/client

proc onSend(connection: QuicConnection, datagram: Datagram) =
  connection.outgoing.putNoWait(datagram)

proc newQuicClientConnection*(local, remote: TransportAddress): QuicConnection =
  let client = newNgtcp2Client(local, remote)
  let state = newOpenConnection(client)
  let connection = newQuicConnection(state)
  client.onSend = proc (datagram: Datagram) = connection.onSend(datagram)
  client.incoming = connection.incoming
  client.handshake = connection.handshake
  connection
