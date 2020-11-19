import chronos
import ngtcp2
import connection

proc isHandshakeCompleted*(connection: Connection): bool =
  ngtcp2_conn_get_handshake_completed(connection.conn).bool

proc onHandshakeCompleted(connection: ptr ngtcp2_conn,
                          userData: pointer): cint {.cdecl.} =
  cast[Connection](userData).handshake.fire()

proc installHandshakeCallback*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.handshake_completed = onHandshakeCompleted
