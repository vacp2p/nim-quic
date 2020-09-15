import ngtcp2

proc connectionId*(id: string): ngtcp2_cid =
  var bytes: seq[uint8] = cast[seq[uint8]](id)
  ngtcp2_cid_init(addr result, addr bytes[0], bytes.len.uint)

var destinationId* = connectionId("\xff\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xff")
var sourceId* = connectionId("\xee\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xee")
var randomId* = connectionId("\xdd\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xdd")

var nextConnectionId = 1'u8

proc getNewConnectionId*(connection: ptr ngtcp2_conn, id: ptr ngtcp2_cid, token: ptr uint8, cidlen: uint, userData: pointer): cint {.cdecl.} =
  echo "GET CONNECTION ID"
  zeroMem(addr id.data[0], cidlen)
  id.data[0] = nextConnectionId
  inc(nextConnectionId)
  id.datalen = cidlen
  zeroMem(token, NGTCP2_STATELESS_RESET_TOKENLEN)
