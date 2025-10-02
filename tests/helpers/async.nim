import pkg/chronos

proc allSucceeded*[T](futures: varargs[Future[T]]): Future[void] =
  ## Returns a future which will complete only when all futures in are
  ## completed.  When a future raises an exception or is cancelled, a
  ## ``Defect`` will be raised.
  for future in futures:
    asyncSpawn(future)
  allFutures(futures)

type WaitGroup* = ref object of RootObj
  ## A synchronization primitive that waits for a collection of 
  ## asynchronous tasks to finish.
  count: int
  fut: Future[void]

proc newWaitGroup*(count: int): WaitGroup =
  doAssert(count >= 0, "WaitGroup count must be non negative number")
  let fut = newFuture[void]("WaitGroup")
  if count == 0:
    fut.complete()
  WaitGroup(count: count, fut: fut)

proc wait*(wg: WaitGroup): Future[void] =
  wg.fut

proc done*(wg: WaitGroup) =
  if wg.count == 0:
    return

  wg.count.dec
  if wg.count == 0 and not wg.fut.finished:
    wg.fut.complete()
