import ../../../basics
import ../../framesorter
import ../../stream
import ../native/connection

type BaseStream* = ref object of StreamState
  stream*: Opt[Stream]
  incoming*: AsyncQueue[seq[byte]]
  connection*: Ngtcp2Connection
  frameSorter*: FrameSorter

proc setUserData*(state: BaseStream, stream: stream.Stream) =
  state.connection.setStreamUserData(stream.id, unsafeAddr state[])

method expire*(state: BaseStream) {.raises: [].} =
  let stream = state.stream.valueOr:
    return
  stream.closed.fire()

proc allowMoreIncomingBytes*(state: BaseStream, amount: uint64) =
  let stream = state.stream.valueOr:
    return
  state.connection.extendStreamOffset(stream.id, amount)
  state.connection.send()
