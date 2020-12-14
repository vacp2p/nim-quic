import pkg/chronos
import ../../stream

template newState*[T: StreamState](): T =
  var state = T()
  state.read = proc(stream: Stream): Future[seq[byte]] =
    read(stream, state)
  state.write = proc(stream: Stream, bytes: seq[byte]): Future[void] =
    write(stream, state, bytes)
  state.close = proc(stream: Stream): Future[void] =
    close(stream, state)
  state.destroy = proc() =
    destroy(state)
  state
