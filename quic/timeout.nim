import chronos

type Timeout* = ref object
  timer: TimerCallback
  onExpiry: proc () {.gcsafe.}
  expired: AsyncEvent

proc setTimer(timeout: Timeout, duration: Duration) =
  proc onTimeout(_: pointer) =
    timeout.expired.fire()
    timeout.onExpiry()
  timeout.timer = setTimer(Moment.fromNow(duration), onTimeout)

const skip = proc () = discard

proc newTimeout*(onExpiry: proc {.gcsafe.} = skip): Timeout =
  Timeout(onExpiry: onExpiry, expired: newAsyncEvent())

proc stop*(timeout: Timeout) =
  if not timeout.timer.isNil:
    timeout.timer.clearTimer()

proc set*(timeout: Timeout, duration: Duration) =
  timeout.stop()
  timeout.expired.clear()
  timeout.setTimer(duration)

proc expired*(timeout: Timeout) {.async.} =
  await timeout.expired.wait()
