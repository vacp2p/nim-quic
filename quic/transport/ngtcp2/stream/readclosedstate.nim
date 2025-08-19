import ../../../basics
import ../../stream
import ../../framesorter
import ./errors
import chronicles

logScope:
  topics = "closed state"

type ReadClosedStream* = ref object of StreamState
  remaining: AsyncQueue[seq[byte]]
  frameSorter: FrameSorter

proc newReadClosedStream*(
    remaining: AsyncQueue[seq[byte]], frameSorter: FrameSorter
): ClosedStream =
  ReadClosedStream(remaining: remaining)

method enter*(state: ReadClosedStream, stream: Stream) =
  discard

method leave*(state: ReadClosedStream) =
  discard

method read*(state: ReadClosedStream): Future[seq[byte]] {.async.} =
  raise newException(ClosedStreamError, "stream is read closed")

method write*(state: ReadClosedStream, bytes: seq[byte]) {.async.} =
  state.connection.send(state.stream.get.id, bytes)

method close*(state: ReadClosedStream) {.async.} =
  discard

method closeWrite*(state: ReadClosedStream) {.async.} =
  discard

method onClose*(state: ReadClosedStream) =
  discard

method isClosed*(state: ReadClosedStream): bool =
  true

method receive*(
    state: ReadClosedStream, offset: uint64, bytes: seq[byte], isFin: bool
) =
  discard

method reset*(state: ReadClosedStream) =
  discard

method expire*(state: ReadClosedStream) {.raises: [].} =
  discard
