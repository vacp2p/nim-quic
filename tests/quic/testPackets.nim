import unittest
import quic
import math

test "there are two kinds of packet headers; short and long":
  discard PacketHeader(kind: headerShort)
  discard PacketHeader(kind: headerLong)

test "packet numbers are in the range 0 to 2^62-1":
  check PacketNumber.low == 0
  check PacketNumber.high == 2'u64 ^ 62 - 1
