import ../errors
import std/tables
import chronos
import heapqueue

type FrameSorter* = ref object of RootRef
  buffer*: Table[int64, seq[byte]] # sparse byte storage
  minHeap: HeapQueue[int64]
  emitPos*: int64 # where to emit data from
  incoming*: AsyncQueue[seq[byte]]
  totalBytes*: Opt[int64]
    # contains total bytes for frame; and is known once a FIN is received
  closed: bool

proc initFrameSorter*(incoming: AsyncQueue[seq[byte]]): FrameSorter =
  return FrameSorter(
    incoming: incoming,
    minHeap: initHeapQueue[int64](),
    buffer: initTable[int64, seq[byte]](),
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

template sendEof(fs: var FrameSorter) =
  if fs.isEOF():
    # empty sequence is sent to unblock reading from incoming queue
    try:
      fs.incoming.putNoWait(@[])
    except AsyncQueueFullError:
      raise newException(QuicError, "Incoming queue is full")

template putToQueue(fs: var FrameSorter, data: sink seq[byte]) =
  if data.len > 0:
    try:
      fs.incoming.putNoWait(data)
    except AsyncQueueFullError:
      raise newException(QuicError, "Incoming queue is full")

  fs.sendEof()

proc emitBufferedData(fs: var FrameSorter) {.raises: [QuicError].} =
  let total =
    if fs.totalBytes.isSome():
      fs.totalBytes.get()
    else:
      int64.high

  while fs.minHeap.len > 0:
    if fs.emitPos >= total: # all bytes are emitted
      return

    let min = fs.minHeap[0]
    var data: seq[byte]
    try:
      data = fs.buffer[min]
    except KeyError:
      doAssert false, "already checked with hasKey"

    if min == fs.emitPos:
      # next element in buffer is exactly at emit pos -> emit whole chunk
      fs.putToQueue(data)
      fs.emitPos += data.len
      fs.buffer.del(min)
      discard fs.minHeap.pop()
    elif fs.emitPos > min and fs.emitPos < (min + data.len):
      # next element in buffer is partially at emit pos -> emit part of chunk
      let diff = fs.emitPos - min
      fs.putToQueue(data[diff .. data.len - 1])
      fs.emitPos += data.len - diff - 1
      fs.buffer.del(min)
      discard fs.minHeap.pop()
    elif fs.emitPos < min:
      # next element in buffer is away from emit pos -> we stop here until next
      return
    else:
      # this element was already emitted -> remove element and continue
      fs.buffer.del(min)
      discard fs.minHeap.pop()

proc close*(fs: var FrameSorter) =
  if fs.closed:
    return
  fs.closed = true
  fs.sendEof()

proc sumBytesInBuffer(fs: FrameSorter): int =
  var sum = 0
  var offset = fs.emitPos

  for min in fs.minHeap:
    var data: seq[byte]
    try:
      data = fs.buffer[min]
    except KeyError:
      doAssert false, "already checked with hasKey"

    if offset == min:
      sum += data.len
      offset += data.len
    elif offset > min and offset < (min + data.len):
      let diff = fs.emitPos - min
      sum += data.len - diff
      offset += data.len - diff

  return sum

proc isComplete*(fs: FrameSorter): bool =
  if fs.closed:
    return true

  if fs.totalBytes.isNone:
    return false

  let total = fs.totalBytes.get()
  return fs.emitPos - 1 + fs.sumBytesInBuffer() >= total

proc insert*(
    fs: var FrameSorter, offset: uint64, data: sink seq[byte], isFin: bool
) {.raises: [QuicError].} =
  if fs.isComplete():
    return

  if isFin:
    fs.totalBytes = Opt.some(offset.int64 + max(data.len - 1, 0))
    defer:
      # send EOF in defer so that it happens after 
      # data is written to incoming queue (if any)
      fs.sendEof()

  if data.len == 0:
    return

  if fs.totalBytes.isSome() and fs.totalBytes.get() < offset.int64:
    return

  # Insert bytes into buffer
  fs.minHeap.push(offset.int64)
  fs.buffer[offset.int64] = data

  # Try to emit contiguous data
  fs.emitBufferedData()

proc reset*(fs: var FrameSorter) =
  fs.totalBytes = Opt.none(int64)
  fs.buffer.clear()
  fs.incoming.clear()
  fs.emitPos = 0
  # resetting FS should leave fs.closed (if it was set)
