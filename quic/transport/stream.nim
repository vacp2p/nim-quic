import pkg/chronos

type
  Stream* = ref object
    id: int64
    state: StreamState
  StreamState* = ref object of RootObj
  StreamError* = object of IOError

method read(state: StreamState,
            stream: Stream): Future[seq[byte]] {.base, async.} =
  doAssert false # override this method

method write(state: StreamState,
             stream: Stream, bytes: seq[byte]) {.base, async.} =
  doAssert false # override this method

method close(state: StreamState, stream: Stream) {.base, async.} =
  doAssert false # override this method

method destroy(state: StreamState) {.base.} =
  doAssert false # override this method

proc newStream*(id: int64, state: StreamState): Stream =
  Stream(state: state)

proc switch*(stream: Stream, newState: StreamState) =
  stream.state.destroy()
  stream.state = newState

proc id*(stream: Stream): int64 =
  stream.id

proc read*(stream: Stream): Future[seq[byte]] {.async.} =
  result = await stream.state.read(stream)

proc write*(stream: Stream, bytes: seq[byte]) {.async.} =
  await stream.state.write(stream, bytes)

proc close*(stream: Stream) {.async.} =
  await stream.state.close(stream)
