template asynctest*(name, body) =
  test name:
    proc asyncproc {.async.} = body
    waitFor asyncproc()
