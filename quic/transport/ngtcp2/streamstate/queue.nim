import ../../../errors
import chronos

type StreamQueue* = ref object of RootRef
  emitPos*: int64 # where to emit data from
  incoming*: AsyncQueue[seq[byte]]
  totalBytes*: Opt[int64]
    # contains total bytes for frame; and is known once a FIN is received
  closed: bool

proc initStreamQueue*(): StreamQueue =
  return StreamQueue(
    incoming: newAsyncQueue[seq[byte]](),
    emitPos: 0,
    totalBytes: Opt.none(int64),
    closed: false,
  )

proc isEOF*(sq: StreamQueue): bool =
  if sq.closed:
    return true

  if sq.totalBytes.isNone:
    return false

  return sq.emitPos >= sq.totalBytes.get()

proc sendEof(sq: var StreamQueue) {.raises: [QuicError].} =
  if sq.isEOF():
    # empty sequence is sent to unblock reading from incoming queue
    try:
      sq.incoming.putNoWait(@[])
    except AsyncQueueFullError:
      raise newException(QuicError, "Incoming queue is full")

proc close*(sq: var StreamQueue) =
  if sq.closed:
    return

  sq.closed = true
  sq.sendEof()

proc insert*(
    sq: var StreamQueue, ofsqet: uint64, data: seq[byte], isFin: bool
) {.raises: [QuicError].} =
  if sq.closed:
    return

  if isFin:
    sq.totalBytes = Opt.some(ofsqet.int64 + max(data.len - 1, 0))

  try:
    if data.len > 0:
      sq.incoming.putNoWait(data)
      sq.emitPos += data.len
  except AsyncQueueFullError:
    raise newException(QuicError, "Incoming queue is full")

  sq.sendEof()

proc reset*(sq: var StreamQueue) =
  sq.totalBytes = Opt.none(int64)
  sq.incoming.clear()
  sq.emitPos = 0
  # resetting FS should leave sq.closed (if it was set)
