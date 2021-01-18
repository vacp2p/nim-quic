import pkg/chronos
import ../../stream
import ./closedstate

type
  DrainingStream* = ref object of StreamState
    stream: Stream
    remaining: AsyncQueue[seq[byte]]
  DrainingStreamError* = object of StreamError

proc newDrainingStream*(messages: AsyncQueue[seq[byte]]): DrainingStream =
  doAssert messages.len > 0
  DrainingStream(remaining: messages)

method enter(state: DrainingStream, stream: Stream) =
  procCall enter(StreamState(state), stream)
  state.stream = stream

method leave(state: DrainingStream) =
  state.stream = nil

method read(state: DrainingStream): Future[seq[byte]] {.async.} =
  result = state.remaining.popFirstNoWait()
  if state.remaining.empty:
    state.stream.switch(newClosedStream())

method write(state: DrainingStream, bytes: seq[byte]) {.async.} =
  raise newException(DrainingStreamError, "stream is draining")

method close(state: DrainingStream) {.async.} =
  state.stream.switch(newClosedStream())
