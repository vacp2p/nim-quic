import ngtcp2
import ../connectionid

proc toCid*(bytes: ptr uint8, length: uint): ngtcp2_cid =
  ngtcp2_cid_init(addr result, bytes, length)

proc toCid*(id: ConnectionId): ngtcp2_cid =
  let bytes = seq[byte](id)
  toCid(unsafeAddr bytes[0], bytes.len.uint)

proc getNewConnectionId(connection: ptr ngtcp2_conn,
                         id: ptr ngtcp2_cid,
                         token: ptr uint8,
                         cidlen: uint,
                         userData: pointer): cint {.cdecl.} =
  id[] = randomConnectionId(cidlen.int).toCid
  zeroMem(token, NGTCP2_STATELESS_RESET_TOKENLEN)

proc installConnectionIdCallback*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.get_new_connection_id = getNewConnectionId
