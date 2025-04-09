import ../errors
import std/[tables, strformat]
import chronos
import std/[algorithm, sequtils]

type
  Gap = object
    start, finish: uint64 # end_ is exclusive

  FrameSorter* = object
    buffer: Table[uint64, byte] # sparse byte storage
    gaps: seq[Gap] # list of missing ranges
    readPos: uint64 # where to emit data from
    incoming: AsyncQueue[seq[byte]]

proc initFrameSorter*(incoming: AsyncQueue[seq[byte]]): FrameSorter =
  result.incoming = incoming
  result.gaps = @[Gap(start: 0, finish: high(uint64))] # start with [0..∞)
  result.buffer = initTable[uint64, byte]()
  result.readPos = 0


proc normalizeGaps(gaps: var seq[Gap]) =
  gaps.sort(proc (a, b: Gap): int =
    return cmp(a.start, b.start)
  )
  var merged: seq[Gap]
  for gap in gaps:
    if merged.len == 0 or merged[^1].finish < gap.start:
      merged.add gap
    else:
      merged[^1].finish = max(merged[^1].finish, gap.finish)
  gaps = merged

proc removeGap(gaps: var seq[Gap], startPos, endPos: uint64) =
  ## Remove [startPos, endPos) from gaps
  var newGaps: seq[Gap]
  for gap in gaps:
    if endPos <= gap.start or startPos >= gap.finish:
      # No overlap
      newGaps.add gap
    else:
      # Overlap exists
      if startPos > gap.start:
        newGaps.add Gap(start: gap.start, finish: startPos)
      if endPos < gap.finish:
        newGaps.add Gap(start: endPos, finish: gap.finish)
  gaps = newGaps

proc insert*(fs: var FrameSorter, offset: uint64, data: openArray[byte]) =
  ## Insert bytes into sparse buffer
  for i, b in data:
    let pos = offset + uint64(i)
    if fs.buffer.hasKey(pos):
      if fs.buffer[pos] != b:
        raise newException(QuicError, &"conflicting byte at position {pos}. protocol violation")
      # else: already same value, nothing to do
    else:
      fs.buffer[pos] = b

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

