import ../errors
import std/tables
import chronos

type FrameSorter* = ref object of RootRef
  buffer*: Table[int64, byte] # sparse byte storage
  emitPos*: int64 # where to emit data from
  incoming*: AsyncQueue[seq[byte]]
  totalBytes*: Opt[int64]
    # contains total bytes for frame; and is known once a FIN is received
  closed: bool

proc initFrameSorter*(incoming: AsyncQueue[seq[byte]]): FrameSorter =
  return FrameSorter(
    incoming: incoming,
    buffer: initTable[int64, byte](),
    emitPos: 0,
    totalBytes: Opt.none(int64),
    closed: false,
  )

proc isEOF*(fs: FrameSorter): bool =
  if fs.closed:
    return true

  if fs.totalBytes.isNone:
    return false

  return fs.emitPos >= fs.totalBytes.get()

proc sendEof(fs: var FrameSorter) {.raises: [QuicError].} =
  if fs.isEOF():
    # empty sequence is sent to unblock reading from incoming queue
    try:
      fs.incoming.putNoWait(@[])
    except AsyncQueueFullError:
      raise newException(QuicError, "Incoming queue is full")

proc putToQueue(fs: var FrameSorter, data: seq[byte]) {.raises: [QuicError].} =
  if data.len > 0:
    try:
      fs.incoming.putNoWait(data)
    except AsyncQueueFullError:
      raise newException(QuicError, "Incoming queue is full")

  fs.sendEof()

proc emitBufferedData(fs: var FrameSorter) {.raises: [QuicError].} =
  var emitData: seq[byte]
  while fs.buffer.hasKey(fs.emitPos):
    try:
      emitData.add fs.buffer[fs.emitPos]
    except KeyError:
      doAssert false, "already checked with hasKey"
    fs.buffer.del(fs.emitPos)
    inc fs.emitPos

  fs.putToQueue(emitData)

proc close*(fs: var FrameSorter) =
  if fs.closed:
    return
  fs.closed = true
  fs.sendEof()

proc insert*(
    fs: var FrameSorter, offset: uint64, data: seq[byte], isFin: bool
) {.raises: [QuicError].} =
  if fs.closed:
    return

  if isFin:
    fs.totalBytes = Opt.some(offset.int64 + max(data.len - 1, 0))
    defer:
      # send EOF in defer so that it happens after 
      # data is written to incoming queue (if any)
      fs.sendEof()

  if data.len == 0:
    return

  # if offset matches emit position, framesorter can emit entire input in batch
  if offset.int == fs.emitPos:
    fs.emitPos += data.len
    fs.putToQueue(data)

    # in addition check if there is buffered data to emit
    fs.emitBufferedData()

    return

  # Insert bytes into sparse buffer
  for i, b in data:
    let pos = offset.int + i

    if fs.totalBytes.isSome and pos > fs.totalBytes.unsafeGet:
      continue
    if fs.buffer.hasKey(pos):
      try:
        if fs.buffer[pos] != b:
          raise newException(QuicError, "conflicting byte received. protocol violation")
        # else: already same value, nothing to do
      except KeyError:
        doAssert false, "already checked with hasKey"
    elif pos >= fs.emitPos: # put data to buffer, avoiding emitted data
      fs.buffer[pos] = b

  # Try to emit contiguous data
  fs.emitBufferedData()

proc reset*(fs: var FrameSorter) =
  fs.totalBytes = Opt.none(int64)
  fs.buffer.clear()
  fs.incoming.clear()
  fs.emitPos = 0

proc isComplete*(fs: FrameSorter): bool =
  if fs.closed:
    return true

  if fs.totalBytes.isNone:
    return false

  let total = fs.totalBytes.unsafeGet
  return fs.emitPos - 1 + len(fs.buffer) >= total
