import pkg/chronos

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
