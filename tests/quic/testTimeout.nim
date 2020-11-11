import unittest
import chronos
import ../helpers/asynctest
import ../../quic/timeout

suite "timeout":

  template measure(body): Duration =
    let start = Moment.now()
    body
    Moment.now() - start

  template checkDuration(duration, minimum: Duration, overshoot = 5.milliseconds) =
    check duration > minimum
    check duration < minimum + overshoot

  asynctest "can expire":
    let duration = measure:
      let timeout = newTimeout()
      timeout.set(10.milliseconds)
      await timeout.expired()
    checkDuration duration, 10.milliseconds

  asynctest "can be reset before expiry":
    let duration = measure:
      let timeout = newTimeout()
      timeout.set(10.milliseconds)
      await sleepAsync(5.milliseconds)
      timeout.set(10.milliseconds)
      await timeout.expired()
    checkDuration duration, 15.milliseconds

  asynctest "can be reset after expiry":
    let duration = measure:
      let timeout = newTimeout()
      timeout.set(10.milliseconds)
      await timeout.expired()
      timeout.set(10.milliseconds)
      await timeout.expired()
    checkDuration duration, 20.milliseconds

  asynctest "can be stopped":
    let timeout = newTimeout()
    timeout.set(10.milliseconds)
    let expiry = timeout.expired()
    await sleepAsync(5.milliseconds)
    timeout.stop()
    await sleepAsync(5.milliseconds)
    check not expiry.finished()
    expiry.cancel()

  asynctest "calls callback after expiry":
    var called = false
    proc callback = called = true
    let timeout = newTimeout(callback)
    timeout.set(10.milliseconds)
    await sleepAsync(5.milliseconds)
    check not called
    await sleepAsync(5.milliseconds)
    check called
    timeout.stop()

  asynctest "calls callback multiple times":
    var count = 0
    proc callback = inc count
    let timeout = newTimeout(callback)
    timeout.set(10.milliseconds)
    await timeout.expired()
    timeout.set(10.milliseconds)
    await timeout.expired()
    check count == 2
