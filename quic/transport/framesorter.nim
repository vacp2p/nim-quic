import ../errors
import std/tables
import chronos

type
  Range = tuple[startPos, endPos: uint64]

  FrameSorter* = object
    buffer*: Table[uint64, byte] # sparse byte storage
    readPos*: uint64 # where to emit data from
    ranges*: seq[Range]
    incoming*: AsyncQueue[seq[byte]]
    lastPos*: Opt[uint64]
      # contains the index for the last position for a stream once a FIN is received

proc initFrameSorter*(incoming: AsyncQueue[seq[byte]]): FrameSorter =
  result.incoming = incoming
  result.buffer = initTable[uint64, byte]()
  result.readPos = 0
  result.lastPos = Opt.none(uint64)

proc insertRanges(fs: var FrameSorter, newStart, newEnd: uint64) =
  var toInsertS = newStart
  var toInsertE = newEnd
  var i = 0
  while i < fs.ranges.len:
    let (s, e) = fs.ranges[i]
    if newEnd + 1 < s:
      break # insert before
    elif newStart > e + 1:
      inc i
    else:
      toInsertS = min(newStart, s)
      toInsertE = max(newEnd, e)
      fs.ranges.delete(i)
      continue
  fs.ranges.insert((toInsertS, toInsertE), i)

proc insert*(
    fs: var FrameSorter, offset: uint64, data: openArray[byte], isFin: bool
) {.raises: [QuicError].} =
  let endPos =
    if data.len != 0:
      offset + uint64(data.len) - 1
    else:
      offset

  if isFin and fs.lastPos.isNone:
    # Remove any data received after the end
    fs.lastPos = Opt.some(endPos)

  # Insert ranges
  let rangeStart = min(fs.lastPos.get(offset), offset)
  let rangeEnd = min(fs.lastPos.get(endPos), endPos)

  # Insert bytes into sparse buffer
  for i, b in data:
    let pos = offset + uint64(i)

    if fs.lastPos.isSome and pos > fs.lastPos.unsafeGet:
      continue

    if fs.buffer.hasKey(pos):
      try:
        if fs.buffer[pos] != b:
          raise newException(QuicError, "conflicting byte received. protocol violation")
      except KeyError:
        doAssert false, "already checked with hasKey"
      # else: already same value, nothing to do
    else:
      fs.buffer[pos] = b

  fs.insertRanges(rangeStart, rangeEnd)

  # Try to emit contiguous data
  var emitData: seq[byte]
  while fs.buffer.hasKey(fs.readPos):
    try:
      emitData.add fs.buffer[fs.readPos]
    except KeyError:
      doAssert false, "already checked with hasKey"
    fs.buffer.del(fs.readPos)
    inc fs.readPos

  if emitData.len > 0:
    try:
      fs.incoming.putNoWait(emitData)
    except AsyncQueueFullError:
      raise newException(QuicError, "Incoming queue is full")

proc isEOF*(fs: FrameSorter): bool =
  if fs.lastPos.isNone:
    return false

  return fs.readPos >= fs.lastPos.get()

proc reset*(fs: var FrameSorter) =
  fs.lastPos = Opt.some(0'u64)
  fs.buffer.clear()
  fs.incoming.clear()
  fs.ranges = @[]
  fs.readPos = 0

proc isComplete*(fs: FrameSorter): bool =
  if fs.lastPos.isNone:
    return false

  if fs.ranges.len == 0:
    return true

  for i in 0 ..< fs.ranges.len - 1:
    let gapStart = fs.ranges[i].endPos + 1
    let gapEnd = fs.ranges[i + 1].startPos - 1
    if gapStart <= gapEnd:
      return false

  return true
