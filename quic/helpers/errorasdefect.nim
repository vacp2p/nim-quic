template errorAsDefect*(body): untyped =
  try:
    body
  except CatchableError as error:
    raise (ref Defect)(msg: error.msg, parent: error)
