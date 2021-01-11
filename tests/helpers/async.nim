import pkg/chronos

proc allSucceeded*[T](futures: varargs[Future[T]]): Future[void] =
  ## Returns a future which will complete only when all futures in are
  ## completed.  When a future raises an exception or is cancelled, a
  ## ``Defect`` will be raised.
  for future in futures:
    asyncSpawn(future)
  allFutures(futures)
