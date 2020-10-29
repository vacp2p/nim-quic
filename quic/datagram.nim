import congestion

type
  Datagram* = object
    data*: seq[byte]
    ecn*: ECN
  DatagramBuffer* = openArray[byte]
