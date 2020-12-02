template asynctest*(name, body) =
  test name:
    let asyncproc = proc {.async.} = body
    waitFor asyncproc()

template asynctest*(name, done, body) =
  asynctest name:
    let event = newAsyncEvent()
    proc `done` {.inject.} = event.fire()
    body
    await event.wait()

template asyncsetup*(body) =
  setup:
    let asyncproc = proc {.async.} = body
    waitFor asyncproc()

template asyncteardown*(body) =
  teardown:
    let asyncproc = proc {.async.} = body
    waitFor asyncproc()
