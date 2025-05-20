import ../errors
import std/tables
import chronos

type FrameSorter* = object
  buffer*: Table[int64, byte] # sparse byte storage
  emitPos*: int64 # where to emit data from
  incoming*: AsyncQueue[seq[byte]]
  totalBytes*: Opt[int64]
    # contains total bytes for frame; and is known once a FIN is received

proc initFrameSorter*(incoming: AsyncQueue[seq[byte]]): FrameSorter =
  result.incoming = incoming
  result.buffer = initTable[int64, byte]()
  result.emitPos = 0
  result.totalBytes = Opt.none(int64)

proc insert*(
    fs: var FrameSorter, offset: uint64, data: openArray[byte], isFin: bool
) {.raises: [QuicError].} =
  if isFin and fs.totalBytes.isNone:
    fs.totalBytes = Opt.some(offset.int64 + max(data.len - 1, 0))

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
  var emitData: seq[byte]
  while fs.buffer.hasKey(fs.emitPos):
    try:
      emitData.add fs.buffer[fs.emitPos]
    except KeyError:
      doAssert false, "already checked with hasKey"
    fs.buffer.del(fs.emitPos)
    inc fs.emitPos

  if emitData.len > 0:
    try:
      fs.incoming.putNoWait(emitData)
    except AsyncQueueFullError:
      raise newException(QuicError, "Incoming queue is full")

proc isEOF*(fs: FrameSorter): bool =
  if fs.totalBytes.isNone:
    return false

  return fs.emitPos >= fs.totalBytes.get()

proc reset*(fs: var FrameSorter) =
  fs.totalBytes = Opt.none(int64)
  fs.buffer.clear()
  fs.incoming.clear()
  fs.emitPos = 0

proc isComplete*(fs: FrameSorter): bool =
  if fs.totalBytes.isNone:
    return false

  let total = fs.totalBytes.unsafeGet
  return fs.emitPos - 1 + len(fs.buffer) >= total
