import unittest
import quic/connectionid

suite "Connection Ids":

  test "generates random ids":
    check randomConnectionId() != randomConnectionId()

  test "random ids are of the correct length":
    check randomConnectionId().len == DefaultConnectionIdLength
