import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic/transport/timeout

suite "timeout":
  template measure(body): Duration =
    let start = Moment.now()
    body
    Moment.now() - start

  asyncTest "can expire":
    let duration = measure:
      let timeout = newTimeout()
      timeout.set(10.milliseconds)
      await timeout.expired()
    check duration > 10.milliseconds

  asyncTest "can be reset before expiry":
    let timeout = newTimeout()
    timeout.set(10.milliseconds)
    let duration = measure:
      timeout.set(20.milliseconds)
      await timeout.expired()
    check duration > 20.milliseconds

  asyncTest "can be reset after expiry":
    let timeout = newTimeout()
    timeout.set(10.milliseconds)
    await timeout.expired()
    let duration = measure:
      timeout.set(10.milliseconds)
      await timeout.expired()
    check duration > 10.milliseconds

  asyncTest "can be stopped":
    let timeout = newTimeout()
    timeout.set(10.milliseconds)
    let expiry = timeout.expired()
    timeout.stop()
    await sleepAsync(10.milliseconds)
    check not expiry.finished()
    expiry.cancel()

  asyncTest "calls callback after expiry":
    var called = false
    proc callback() =
      called = true

    let timeout = newTimeout(callback)
    timeout.set(10.milliseconds)
    check not called
    await timeout.expired()
    check called
    timeout.stop()

  asyncTest "calls callback multiple times":
    var count = 0
    proc callback() =
      inc count

    let timeout = newTimeout(callback)
    timeout.set(10.milliseconds)
    await timeout.expired()
    timeout.set(10.milliseconds)
    await timeout.expired()
    check count == 2

  asyncTest "timeout can be set to a moment in time":
    let duration = measure:
      let timeout = newTimeout()
      timeout.set(Moment.fromNow(10.milliseconds))
      await timeout.expired()
    check duration > 10.milliseconds
