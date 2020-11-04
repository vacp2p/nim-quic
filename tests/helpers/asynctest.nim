template asynctest*(name, body) =
  test name:
    let asyncproc = proc {.async.} = body
    waitFor asyncproc()

template asyncsetup*(body) =
  setup:
    let asyncproc = proc {.async.} = body
    waitFor asyncproc()

template asyncteardown*(body) =
  teardown:
    let asyncproc = proc {.async.} = body
    waitFor asyncproc()
