import ../../../basics
import ../../stream
import ./closedstate

type
  DrainingStream* = ref object of StreamState
    stream: ?Stream
    remaining: AsyncQueue[seq[byte]]
  DrainingStreamError* = object of StreamError

proc newDrainingStream*(messages: AsyncQueue[seq[byte]]): DrainingStream =
  doAssert messages.len > 0
  DrainingStream(remaining: messages)

{.push locks:"unknown".}

method enter(state: DrainingStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = some stream

method leave(state: DrainingStream) =
  state.stream = Stream.none

method read(state: DrainingStream): Future[seq[byte]] {.async.} =
  result = state.remaining.popFirstNoWait()
  if state.remaining.empty and stream =? state.stream:
    stream.switch(newClosedStream())

method write(state: DrainingStream, bytes: seq[byte]) {.async.} =
  raise newException(DrainingStreamError, "stream is draining")

method close(state: DrainingStream) {.async.} =
  if stream =? state.stream:
    stream.switch(newClosedStream())

method onClose(state: DrainingStream) =
  discard

method isClosed*(state: DrainingStream): bool =
  false

{.pop.}
