import congestion

type
  Datagram* = object
    data*: seq[byte]
    ecn*: ECN
  DatagramBuffer* = openArray[byte]


proc len*(datagram: Datagram): int =
  datagram.data.len
