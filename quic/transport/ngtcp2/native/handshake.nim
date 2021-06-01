import pkg/ngtcp2
import pkg/questionable
import ./connection

proc isHandshakeCompleted*(connection: Ngtcp2Connection): bool =
  ngtcp2_conn_get_handshake_completed(!connection.conn).bool

proc onHandshakeDone(connection: ptr ngtcp2_conn,
                          userData: pointer): cint {.cdecl.} =
  cast[Ngtcp2Connection](userData).onHandshakeDone()

proc installServerHandshakeCallback*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.handshake_completed = onHandshakeDone

proc installClientHandshakeCallback*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.handshake_confirmed = onHandshakeDone
