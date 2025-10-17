import ngtcp2
import ./connection

proc onHandshakeDone(connection: ptr ngtcp2_conn, userData: pointer): cint {.cdecl.} =
  cast[Ngtcp2Connection](userData).onHandshakeDone()

proc installHandshakeCallback*(callbacks: var ngtcp2_callbacks) =
  callbacks.handshake_completed = onHandshakeDone
