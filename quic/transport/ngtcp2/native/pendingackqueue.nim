import std/deques
import ../../../helpers/sequninit

type Buffer = ref object
  data*: seq[byte]
  offset*: uint64

template endPos*(b: Buffer): uint64 =
  b.offset + b.data.len.uint64 - 1

type PendingAckQueue* = ref object
  ackedNext*: uint64
  buffers*: Deque[Buffer]

proc new*(T: typedesc[PendingAckQueue]): T =
  PendingAckQueue(ackedNext: 0)

proc isEmpty*(q: PendingAckQueue): bool =
  q.buffers.len == 0

proc nextOffset*(q: PendingAckQueue): uint64 =
  if q.isEmpty():
    q.ackedNext
  else:
    q.buffers.peekLast.endPos + 1

proc push*(q: PendingAckQueue, data: sink seq[byte]) =
  if data.len == 0:
    return
  let buffer = Buffer(data: move data, offset: q.nextOffset())
  q.buffers.addLast(buffer)

proc ack*(q: PendingAckQueue, offset: uint64, length: uint64) =
  if length == 0:
    return
  let newAckEnd = offset + length
  if newAckEnd <= q.ackedNext or offset > q.ackedNext:
    return
  q.ackedNext = newAckEnd
  while not q.isEmpty() and q.buffers.peekFirst.endPos < q.ackedNext:
    discard q.buffers.popFirst()
