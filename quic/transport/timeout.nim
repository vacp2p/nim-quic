import ../basics
import chronicles

type Timeout* = ref object
  timer: Opt[TimerCallback]
  onExpiry: proc() {.gcsafe, raises: [].}
  expired: AsyncEvent

proc setTimer(timeout: Timeout, moment: Moment) =
  trace "setTimer"
  proc onTimeout(_: pointer) =
    timeout.expired.fire()
    timeout.onExpiry()

  timeout.timer = Opt.some(setTimer(moment, onTimeout))

const skip = proc() =
  discard

proc newTimeout*(onExpiry: proc() {.gcsafe, raises: [].} = skip): Timeout =
  trace "newTimeout"
  Timeout(onExpiry: onExpiry, expired: newAsyncEvent())

proc stop*(timeout: Timeout) =
  if timeout.timer.isSome():
    timeout.timer.unsafeGet().clearTimer()

proc set*(timeout: Timeout, moment: Moment) =
  timeout.stop()
  timeout.expired.clear()
  timeout.setTimer(moment)

proc set*(timeout: Timeout, duration: Duration) =
  timeout.set(Moment.fromNow(duration))

proc expired*(timeout: Timeout) {.async.} =
  await timeout.expired.wait()
  trace "expired"
