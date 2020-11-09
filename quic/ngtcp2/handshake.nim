import ngtcp2
import connection

proc isHandshakeCompleted*(connection: Connection): bool =
  ngtcp2_conn_get_handshake_completed(connection.conn).bool
