import ngtcp2
import ../../../errors

type Ngtcp2Error* = ref object of QuicError
  code*: cint

# Note: Ngtcp2FatalError is intentionally not ref object of QuicError
# because it needs different case for handling compared to QuicError.
# If it was QuicError, it would be hard to notice places where we need handle this error.
type Ngtcp2FatalError* = ref object of CatchableError
  code*: cint

proc checkResult*(retCode: cint) {.raises: [QuicError, Ngtcp2FatalError].} =
  if retCode >= 0:
    return

  if ngtcp2_err_is_fatal(retCode) != 0:
    let e = new(Ngtcp2FatalError)
    e.code = retCode
    raise e

  let e = new(Ngtcp2Error)
  e.code = retCode
  raise e
