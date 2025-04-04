import ngtcp2
import ./connection

proc onHandshakeDone(connection: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  cast[Ngtcp2Connection](userData).onHandshakeDone()

proc installServerHandshakeCallback*(callbacks: var ngtcp2_callbacks) =
  callbacks.handshake_completed = onHandshakeDone

proc installClientHandshakeCallback*(callbacks: var ngtcp2_callbacks) =
  callbacks.handshake_confirmed = onHandshakeDone
