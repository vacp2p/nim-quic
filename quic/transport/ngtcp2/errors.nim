import pkg/ngtcp2

type
  Ngtcp2Error* = object of IOError
  Ngtcp2RecoverableError* = object of Ngtcp2Error
  Ngtcp2FatalError* = object of Ngtcp2Error

proc checkResult*(result: cint) =
  if result < 0:
    let msg = $ngtcp2_strerror(result)
    if ngtcp2_err_is_fatal(result) != 0:
      raise newException(Ngtcp2FatalError, msg)
    else:
      raise newException(Ngtcp2RecoverableError, msg)
