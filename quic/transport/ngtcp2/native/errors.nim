import pkg/ngtcp2
import ../../../errors

type
  Ngtcp2Error* = object of QuicError
  Ngtcp2Defect* = object of QuicDefect

proc checkResult*(result: cint) =
  if result < 0:
    let msg = $ngtcp2_strerror(result)
    if ngtcp2_err_is_fatal(result) != 0:
      raise newException(Ngtcp2Defect, msg)
    else:
      raise newException(Ngtcp2Error, msg)
