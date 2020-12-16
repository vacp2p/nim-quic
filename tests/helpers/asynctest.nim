import pkg/chronos

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

proc allSucceeded*[T](futures: varargs[Future[T]]): Future[void] =
  ## Returns a future which will complete only when all futures in are
  ## completed.  When a future raises an exception or is cancelled, a
  ## ``Defect`` will be raised.
  for future in futures:
    asyncSpawn(future)
  allFutures(futures)
