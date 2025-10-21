import ngtcp2
import chronicles
import ../../../errors

logScope:
  topics = "ngtcp2 error"

type Ngtcp2Error* = ref object of QuicError
  code*: cint
  isFatal*: bool

proc checkResult*(result: cint) {.raises: [Ngtcp2Error].} =
  if result >= 0:
    return

  let e = new(Ngtcp2Error)
  e.code = result
  e.isFatal = ngtcp2_err_is_fatal(result) != 0
  e.msg = $ngtcp2_strerror(result)

  if e.isFatal:
    error "Created fatal error", code = e.code, msg = e.msg

  raise e
