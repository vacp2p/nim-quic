import std/unittest
import pkg/chronos
import pkg/quic/timeout
import ../helpers/asynctest

suite "timeout":

  template measure(body): Duration =
    let start = Moment.now()
    body
    Moment.now() - start

  asynctest "can expire":
    let duration = measure:
      let timeout = newTimeout()
      timeout.set(10.milliseconds)
      await timeout.expired()
    check duration > 10.milliseconds

  asynctest "can be reset before expiry":
    let timeout = newTimeout()
    timeout.set(10.milliseconds)
    let duration = measure:
      timeout.set(20.milliseconds)
      await timeout.expired()
    check duration > 20.milliseconds

  asynctest "can be reset after expiry":
    let timeout = newTimeout()
    timeout.set(10.milliseconds)
    await timeout.expired()
    let duration = measure:
      timeout.set(10.milliseconds)
      await timeout.expired()
    check duration > 10.milliseconds

  asynctest "can be stopped":
    let timeout = newTimeout()
    timeout.set(10.milliseconds)
    let expiry = timeout.expired()
    timeout.stop()
    await sleepAsync(10.milliseconds)
    check not expiry.finished()
    expiry.cancel()

  asynctest "calls callback after expiry":
    var called = false
    proc callback = called = true
    let timeout = newTimeout(callback)
    timeout.set(10.milliseconds)
    check not called
    await timeout.expired()
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

  asynctest "timeout can be set to a moment in time":
    let duration = measure:
      let timeout = newTimeout()
      timeout.set(Moment.fromNow(10.milliseconds))
      await timeout.expired()
    check duration > 10.milliseconds
