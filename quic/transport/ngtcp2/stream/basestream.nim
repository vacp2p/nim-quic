import ../../../basics
import ../../framesorter
import ../../stream
import ../native/connection

type BaseStream* = ref object of StreamState
  stream*: Opt[Stream]
  incoming*: AsyncQueue[seq[byte]]
  connection*: Ngtcp2Connection
  frameSorter*: FrameSorter
