type
  QuicError* = object of IOError
  QuicDefect* = object of Defect

template errorAsDefect*(body): untyped =
  try:
    body
  except CatchableError as error:
    raise (ref QuicDefect)(msg: error.msg, parent: error)
