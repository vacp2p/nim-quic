import ../basics
import ../helpers/bits

type
  Stream* = ref object
    id: int64
    state: StreamState
    closed*: AsyncEvent
    lock: AsyncLock

  StreamState* = ref object of RootObj
    entered: bool

  StreamError* = object of QuicError

method enter*(state: StreamState, stream: Stream) {.base, raises: [QuicError].} =
  doAssert not state.entered, "states are not reentrant"
  state.entered = true

method leave*(state: StreamState) {.base, raises: [QuicError].} =
  discard

method read*(
    state: StreamState
): Future[seq[byte]] {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "override method: read"

method write*(
    state: StreamState, bytes: seq[byte]
) {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "override method: write"

method close*(
    state: StreamState
) {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "override method: close"

method closeWrite*(
    state: StreamState
) {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "override method: closeWrite"

method closeRead*(
    state: StreamState
) {.base, async: (raises: [CancelledError, QuicError]).} =
  raiseAssert "override method: closeRead"

method reset*(state: StreamState) {.base, raises: [QuicError].} =
  raiseAssert "override method: reset"

method onClose*(state: StreamState) {.base, raises: [QuicError].} =
  raiseAssert "override method: onClose"

method isClosed*(state: StreamState): bool {.base, raises: [].} =
  raiseAssert "override method: isClosed"

method receive*(
    state: StreamState, offset: uint64, bytes: seq[byte], isFin: bool
) {.base, raises: [QuicError].} =
  raiseAssert "override method: receive"

method expire*(state: StreamState) {.base, raises: [].} =
  raiseAssert "override method: expire"

proc newStream*(id: int64, state: StreamState): Stream {.raises: [QuicError].} =
  let stream =
    Stream(state: state, id: id, closed: newAsyncEvent(), lock: newAsyncLock())
  state.enter(stream)
  stream

proc switch*(stream: Stream, newState: StreamState) {.raises: [QuicError].} =
  stream.state.leave()
  stream.state = newState
  stream.state.enter(stream)

proc id*(stream: Stream): int64 =
  stream.id

proc read*(stream: Stream): Future[seq[byte]] {.async.} =
  result = await stream.state.read()

proc write*(stream: Stream, bytes: seq[byte]) {.async.} =
  # Writing has to be serialized on the same stream as otherwise
  # data might not be sent correctly.
  await stream.lock.acquire()
  defer:
    stream.lock.release()

  await stream.state.write(bytes)

proc close*(stream: Stream) {.async.} =
  await stream.state.close()

proc closeWrite*(stream: Stream) {.async.} =
  await stream.state.closeWrite()

proc closeRead*(stream: Stream) {.async.} =
  await stream.state.closeRead()

proc reset*(stream: Stream) =
  stream.state.reset()

proc onClose*(stream: Stream) =
  stream.state.onClose()

proc isClosed*(stream: Stream): bool =
  stream.state.isClosed()

proc isUnidirectional*(stream: Stream): bool =
  stream.id.byte.bits[6].bool

proc expire*(stream: Stream) {.raises: [].} =
  stream.state.expire()
