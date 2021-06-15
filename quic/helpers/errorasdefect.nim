import ../errors

template errorAsDefect*(body): untyped =
  try:
    body
  except CatchableError as error:
    raise (ref QuicDefect)(msg: error.msg, parent: error)
