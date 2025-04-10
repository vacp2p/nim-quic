import ../errors
import std/[algorithm, strformat, tables]
import chronos

const streamEnd = high(uint64)

type
  Gap = object
    startPos: uint64
    endPos: uint64 # endPos is exclusive

  FrameSorter* = object
    buffer: Table[uint64, byte] # sparse byte storage
    gaps: seq[Gap] # list of missing ranges
    readPos: uint64 # where to emit data from
    incoming: AsyncQueue[seq[byte]]
    finReceived: bool # true if stream sent FIN

proc initFrameSorter*(incoming: AsyncQueue[seq[byte]]): FrameSorter =
  result.incoming = incoming
  result.gaps = @[Gap(startPos: 0, endPos: streamEnd)] # start with [0..∞)
  result.buffer = initTable[uint64, byte]()
  result.readPos = 0

proc normalizeGaps(gaps: var seq[Gap]) =
  gaps.sort(
    proc(a, b: Gap): int =
      return cmp(a.startPos, b.startPos)
  )
  var merged: seq[Gap]
  for gap in gaps:
    if merged.len == 0 or merged[^1].endPos < gap.startPos:
      merged.add gap
    else:
      merged[^1].endPos = max(merged[^1].endPos, gap.endPos)
  gaps = merged

proc removeGap(gaps: var seq[Gap], startPos, endPos: uint64) =
  ## Remove [startPos, endPos) from gaps
  var newGaps: seq[Gap]
  for gap in gaps:
    if endPos <= gap.startPos or startPos >= gap.endPos:
      # No overlap
      newGaps.add gap
    else:
      # Overlap exists
      if startPos > gap.startPos:
        newGaps.add Gap(startPos: gap.startPos, endPos: startPos)
      if endPos < gap.endPos:
        newGaps.add Gap(startPos: endPos, endPos: gap.endPos)
  gaps = newGaps

proc insert*(fs: var FrameSorter, offset: uint64, data: openArray[byte], isFin: bool) =
  ## Insert bytes into sparse buffer
  for i, b in data:
    let pos = offset + uint64(i)
    if fs.buffer.hasKey(pos):
      if fs.buffer[pos] != b:
        raise newException(
          QuicError, &"conflicting byte at position {pos}. protocol violation"
        )
      # else: already same value, nothing to do
    else:
      fs.buffer[pos] = b

  if isFin:
    # Remove any data received after the end
    fs.finReceived = true
    removeGap(fs.gaps, offset + uint64(data.len), streamEnd)
  else:
    # Remove filled range from gaps
    removeGap(fs.gaps, offset, offset + uint64(data.len))

  normalizeGaps(fs.gaps)

  # Try to emit contiguous data
  var emitData: seq[byte]
  while true:
    if fs.buffer.hasKey(fs.readPos):
      emitData.add fs.buffer[fs.readPos]
      fs.buffer.del(fs.readPos)
      inc fs.readPos
    else:
      break

  if emitData.len > 0:
    fs.incoming.putNoWait(emitData)

# TODO: use this function to determine when a stream is ended
#       ngtcp2_conn_shutdown_stream will also need to be replaced
#       by a normal write with FIN flag
proc isComplete*(fs: FrameSorter): bool =
  ## True if all data is received and fin flag is seen
  if not fs.finReceived:
    return false
  for gap in fs.gaps:
    if gap.startPos < streamEnd:
      return false
  return true
