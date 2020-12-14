import pkg/chronos

type
  Stream* = ref object
    id: int64
    state: StreamState
  StreamState* = ref object of RootObj
    read*: proc(stream: Stream): Future[seq[byte]] {.gcsafe.}
    write*: proc(stream: Stream, bytes: seq[byte]): Future[void] {.gcsafe.}
    close*: proc(stream: Stream): Future[void] {.gcsafe.}
    destroy*: proc() {.gcsafe.}
  StreamError* = object of IOError

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
