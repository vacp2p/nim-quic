import pkg/ngtcp2
import pkg/questionable
import ../../helpers/openarray
import ../connectionid
import ./connection

proc toCid*(bytes: ptr uint8, length: uint): ngtcp2_cid =
  ngtcp2_cid_init(addr result, bytes, length)

proc toCid*(id: ConnectionId): ngtcp2_cid =
  let bytes = seq[byte](id)
  toCid(bytes.toUnsafePtr, bytes.len.uint)

proc toConnectionId*(id: ptr ngtcp2_cid): ConnectionId =
  ConnectionId(id.data[0..<id.datalen])

proc getNewConnectionId(conn: ptr ngtcp2_conn,
                        id: ptr ngtcp2_cid,
                        token: ptr uint8,
                        cidlen: uint,
                        userData: pointer): cint {.cdecl.} =

  let newId = randomConnectionId(cidlen.int)
  id[] = newId.toCid
  zeroMem(token, NGTCP2_STATELESS_RESET_TOKENLEN)

  let connection = cast[Ngtcp2Connection](userData)
  if onNewId =? connection.onNewId:
    onNewId(newId)

proc removeConnectionId(conn: ptr ngtcp2_conn,
                        id: ptr ngtcp2_cid,
                        userData: pointer): cint {.cdecl.} =
  let connection = cast[Ngtcp2Connection](userData)
  if onRemoveId =? connection.onRemoveId:
    onRemoveId(id.toConnectionId)

proc installConnectionIdCallback*(callbacks: var ngtcp2_conn_callbacks) =
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.remove_connection_id = removeConnectionId
