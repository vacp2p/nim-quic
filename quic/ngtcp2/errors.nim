import pkg/ngtcp2

type Ngtcp2Error* = object of IOError

proc checkResult*(result: cint) =
  if result < 0:
    raise newException(Ngtcp2Error, $ngtcp2_strerror(result))
