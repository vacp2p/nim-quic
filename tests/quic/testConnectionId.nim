import unittest2
import bearssl/rand
import quic/transport/connectionid
import quic/helpers/rand

suite "connection ids":
  var rng: ref HmacDrbgContext
  setup:
    rng = newRng()

  test "generates random ids":
    for i in 0 ..< 100:
      check randomConnectionId(rng) != randomConnectionId(rng)

  test "random ids are of the correct length":
    check randomConnectionId(rng).len == DefaultConnectionIdLength

  test "random ids can have custom length":
    check randomConnectionId(rng, 5).len == 5
