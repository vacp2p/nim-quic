import chronos

type Timeout* = ref object
  timer: TimerCallback
  callback: proc () {.gcsafe.}
  expired: AsyncEvent

proc setTimer(timeout: Timeout, duration: Duration) =
  proc onTimeout(_: pointer) =
    timeout.expired.fire()
    timeout.callback()
  timeout.timer = setTimer(Moment.fromNow(duration), onTimeout)

const skip = proc () = discard

proc newTimeout*(duration: Duration, callback: proc {.gcsafe.} = skip): Timeout =
  new result
  result.expired = newAsyncEvent()
  result.callback = callback
  result.setTimer(duration)

proc reset*(timeout: Timeout, duration: Duration) =
  timeout.timer.clearTimer()
  timeout.expired.clear()
  timeout.setTimer(duration)

proc stop*(timeout: Timeout) =
  timeout.timer.clearTimer()

proc expired*(timeout: Timeout) {.async.} =
  await timeout.expired.wait()
