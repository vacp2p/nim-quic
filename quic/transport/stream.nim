import ../basics
import ../helpers/bits

type
  Stream* = ref object
    id: int64
    state: StreamState
    closed*: AsyncEvent

  StreamState* = ref object of RootObj
    entered: bool

  StreamError* = object of QuicError

{.push raises: [QuicError].}

method enter*(state: StreamState, stream: Stream) {.base.} =
  doAssert not state.entered # states are not reentrant
  state.entered = true

method leave*(state: StreamState) {.base.} =
  discard

method read*(state: StreamState): Future[seq[byte]] {.base, async.} =
  doAssert false, "override this method"

method write*(state: StreamState, bytes: seq[byte]) {.base, async.} =
  doAssert false, "override this method"

method close*(state: StreamState) {.base, async.} =
  doAssert false, "override this method"

method closeWrite*(state: StreamState) {.base, async.} =
  doAssert false, "override this method"

method closeRead*(state: StreamState) {.base, async.} =
  doAssert false, "override this method"

method reset*(state: StreamState) {.base.} =
  doAssert false, "override this method"

method onClose*(state: StreamState) {.base.} =
  doAssert false, "override this method"

method isClosed*(state: StreamState): bool {.base, raises: [].} =
  doAssert false, "override this method"

method receive*(
    state: StreamState, offset: uint64, bytes: seq[byte], isFin: bool
) {.base.} =
  doAssert false, "override this method"

{.pop.}

method expire*(state: StreamState) {.base, raises: [].} =
  doAssert false, "override this method"

proc newStream*(id: int64, state: StreamState): Stream =
  let stream = Stream(state: state, id: id, closed: newAsyncEvent())
  state.enter(stream)
  stream

proc switch*(stream: Stream, newState: StreamState) =
  stream.state.leave()
  stream.state = newState
  stream.state.enter(stream)

proc id*(stream: Stream): int64 =
  stream.id

proc read*(stream: Stream): Future[seq[byte]] {.async.} =
  result = await stream.state.read()

proc write*(stream: Stream, bytes: seq[byte]) {.async.} =
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
