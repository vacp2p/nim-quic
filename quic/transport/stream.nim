import pkg/chronos

type
  Stream* = ref object
    id: int64
    state: StreamState
  StreamState* = ref object of RootObj
  StreamError* = object of IOError

method enter(state: StreamState, stream: Stream) {.base.} =
  discard

method leave(state: StreamState) {.base.} =
  discard

method read(state: StreamState): Future[seq[byte]] {.base, async.} =
  doAssert false # override this method

method write(state: StreamState, bytes: seq[byte]) {.base, async.} =
  doAssert false # override this method

method close(state: StreamState) {.base, async.} =
  doAssert false # override this method

proc newStream*(id: int64, state: StreamState): Stream =
  let stream = Stream(state: state, id: id)
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
