type
  QuicDefect* = object of Defect
  QuicConfigError* = object of CatchableError
  QuicError* = object of IOError
  ClosedStreamError* = object of QuicError

template errorAsDefect*(body): untyped =
  try:
    body
  except CatchableError as error:
    raise (ref QuicDefect)(msg: error.msg, parent: error)
