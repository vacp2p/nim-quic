import chronos

type Timeout* = ref object
  timer: TimerCallback
  expired: AsyncEvent

proc setTimer(timeout: Timeout, duration: Duration) =
  proc onTimeout(_: pointer) =
    timeout.expired.fire()
  timeout.timer = setTimer(Moment.fromNow(duration), onTimeout)

proc newTimeout*(duration: Duration): Timeout =
  new result
  result.expired = newAsyncEvent()
  result.setTimer(duration)

proc reset*(timeout: Timeout, duration: Duration) =
  timeout.timer.clearTimer()
  timeout.expired.clear()
  timeout.setTimer(duration)

proc stop*(timeout: Timeout) =
  timeout.timer.clearTimer()

proc expired*(timeout: Timeout) {.async.} =
  await timeout.expired.wait()
