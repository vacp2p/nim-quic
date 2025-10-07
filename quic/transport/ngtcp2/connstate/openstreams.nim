import std/sequtils
import ../../../basics
import ../../stream

type OpenStreams* = ref object
  ## Keeps track of streams that are open.
  ## Once a stream closes, it is removed.
  streams: seq[Stream]

proc new*(_: type OpenStreams): OpenStreams =
  OpenStreams()

proc remove(streams: OpenStreams, stream: Stream) =
  streams.streams.keepItIf(it != stream)

proc add*(streams: OpenStreams, stream: Stream) =
  proc handleClose() {.async.} =
    await stream.closed.wait()
    streams.remove(stream)

  streams.streams.add(stream)
  asyncSpawn handleClose()

proc closeAll*(streams: OpenStreams) =
  for stream in streams.streams:
    stream.onClose()
  streams.streams = @[]

proc expireAll*(streams: OpenStreams) =
  for stream in streams.streams:
    stream.expire()
  streams.streams = @[]
