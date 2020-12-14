import ./congestion

type
  Datagram* = object
    data*: seq[byte]
    ecn*: ECN

proc len*(datagram: Datagram): int =
  datagram.data.len
