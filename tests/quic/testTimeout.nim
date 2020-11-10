import unittest
import chronos
import ../helpers/asynctest
import ../../quic/timeout

suite "timeout":

  template measure(body): Duration =
    let start = Moment.now()
    body
    Moment.now() - start

  proc `~=`(actual, expected: Duration, precision = 5.milliseconds): bool =
    expected <= actual and actual < expected + precision

  asynctest "can expire":
    let duration = measure:
      let timeout = newTimeout(10.milliseconds)
      await timeout.expired()
    check duration ~= 10.milliseconds

  asynctest "can be reset before expiry":
    let duration = measure:
      let timeout = newTimeout(10.milliseconds)
      await sleepAsync(5.milliseconds)
      timeout.reset(10.milliseconds)
      await timeout.expired()
    check duration ~= 15.milliseconds

  asynctest "can be reset after expiry":
    let duration = measure:
      let timeout = newTimeout(10.milliseconds)
      await timeout.expired()
      timeout.reset(10.milliseconds)
      await timeout.expired()
    check duration ~= 20.milliseconds

  asynctest "can be stopped":
    let timeout = newTimeout(10.milliseconds)
    let expiry = timeout.expired()
    await sleepAsync(5.milliseconds)
    timeout.stop()
    await sleepAsync(5.milliseconds)
    check not expiry.finished()
    expiry.cancel()
