import pkg/chronos
import pkg/ngtcp2
import ./connection

proc isHandshakeCompleted*(connection: Ngtcp2Connection): bool =
  ngtcp2_conn_get_handshake_completed(connection.conn).bool

proc onHandshakeCompleted(connection: ptr ngtcp2_conn,
                          userData: pointer): cint {.cdecl.} =
  cast[Ngtcp2Connection](userData).handshake.fire()

proc installServerHandshakeCallback*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.handshake_completed = onHandshakeCompleted

proc installClientHandshakeCallback*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.handshake_confirmed = onHandshakeCompleted
