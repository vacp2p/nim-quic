import ./congestion

type Datagram* = ref object
  data*: seq[byte]
  ecn*: ECN

proc len*(datagram: Datagram): int =
  datagram.data.len
