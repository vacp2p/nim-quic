import ../errors
import std/[strformat, tables]
import chronos

type
  FrameSorter* = object
    buffer: Table[uint64, byte] # sparse byte storage
    readPos: uint64 # where to emit data from
    incoming: AsyncQueue[seq[byte]]
    lastPos: Opt[uint64] # contains the index for the last position for a stream once a FIN is received

proc initFrameSorter*(incoming: AsyncQueue[seq[byte]]): FrameSorter =
  result.incoming = incoming
  result.buffer = initTable[uint64, byte]()
  result.readPos = 0
  result.lastPos = Opt.none(uint64)

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
    fs.lastPos = Opt.some(offset + uint64(data.len) - 1)

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
  if fs.lastPos.isNone:
    return false

  return  fs.readPos > fs.lastPos.get()