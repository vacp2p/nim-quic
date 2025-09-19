import pkg/chronos
import pkg/unittest2
import pkg/quic/transport/stream

proc newData*(size: int, val: uint8 = uint8(0xEE)): seq[uint8] =
  var data = newSeq[uint8](size)
  for i in 0 ..< size:
    data[i] = val
  return data

proc readStreamTillEOF*(
    stream: Stream, maxBytes: int = int.high
): Future[seq[uint8]] {.async.} =
  ## Reads from stream until EOF is reached or the received data size meets/exceeds maxBytes

  var receivedData: seq[uint8]
  while true:
    let chunk = await stream.read()
    if chunk.len == 0:
      break
    receivedData.add(chunk)
    if receivedData.len >= maxBytes:
      break
  return receivedData

proc checkEqual*(a: seq[byte], b: seq[byte]) =
  if a.len != b.len:
    checkpoint("sequences do not have the same length: " & $a.len & " != " & $b.len)
    fail()
    return

  for i in 0 ..< a.len:
    if a[i] != b[i]:
      checkpoint("sequences do not have same data")
      fail()
      return
