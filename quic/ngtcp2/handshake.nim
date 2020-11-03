import chronos
import ngtcp2
import connection
import udp

proc isHandshakeCompleted*(connection: Connection): bool =
  ngtcp2_conn_get_handshake_completed(connection.conn).bool

proc handshake*(connection: Connection) {.async.} =
  while not connection.isHandshakeCompleted:
    await connection.send()
