import ngtcp2
import ../connectionid

proc connectionId*(bytes: ptr uint8, length: uint): ngtcp2_cid =
  ngtcp2_cid_init(addr result, bytes, length)

proc toCid*(id: ConnectionId): ngtcp2_cid =
  let bytes = seq[byte](id)
  ngtcp2_cid_init(addr result, unsafeAddr bytes[0], bytes.len.uint)

var nextConnectionId = 1'u8

proc getNewConnectionId*(connection: ptr ngtcp2_conn, id: ptr ngtcp2_cid, token: ptr uint8, cidlen: uint, userData: pointer): cint {.cdecl.} =
  zeroMem(addr id.data[0], cidlen)
  id.data[0] = nextConnectionId
  inc(nextConnectionId)
  id.datalen = cidlen
  zeroMem(token, NGTCP2_STATELESS_RESET_TOKENLEN)
