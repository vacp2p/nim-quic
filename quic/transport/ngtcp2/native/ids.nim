import ngtcp2
import ../../../basics
import ../../../helpers/openarray
import ../../connectionid
import ./connection

proc toCid*(bytes: ptr uint8, length: uint): ngtcp2_cid =
  ngtcp2_cid_init(addr result, bytes, length)

proc toCid*(id: ConnectionId): ngtcp2_cid =
  let bytes = seq[byte](id)
  toCid(bytes.toUnsafePtr, bytes.len.uint)

proc toConnectionId*(id: ptr ngtcp2_cid): ConnectionId =
  ConnectionId(id.data[0 ..< id.datalen])

proc getNewConnectionId(
    conn: ptr ngtcp2_conn,
    id: ptr ngtcp2_cid,
    token: ptr uint8,
    cidlen: csize_t,
    userData: pointer,
): cint {.cdecl.} =
  # TODO: should ngtcp2_crypto_generate_stateless_reset_token so
  # we can signal the other peer that the connection is no longer valid?
  # ngtcp2_crypto_generate_stateless_reset_token(
  #   token, some_static_secret_data, config.static_secret.size(), cid) !=
  # 0) 

  let connection = cast[Ngtcp2Connection](userData)
  let newId = randomConnectionId(connection.rng, cidlen.int)
  id[] = newId.toCid
  zeroMem(token, NGTCP2_STATELESS_RESET_TOKENLEN)

  let onNewId = connection.onNewId.valueOr:
    return
  onNewId(newId)
  return 0

proc removeConnectionId(
    conn: ptr ngtcp2_conn, id: ptr ngtcp2_cid, userData: pointer
): cint {.cdecl.} =
  let
    connection = cast[Ngtcp2Connection](userData)
    onRemoveId = connection.onRemoveId.valueOr:
      return
  onRemoveId(id.toConnectionId)

proc installConnectionIdCallback*(callbacks: var ngtcp2_callbacks) =
  callbacks.get_new_connection_id = getNewConnectionId
  callbacks.remove_connection_id = removeConnectionId
