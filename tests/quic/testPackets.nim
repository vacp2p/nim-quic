import unittest
import quic

test "there are two kinds of packet headers; short and long":
  discard PacketHeader(kind: headerShort)
  discard PacketHeader(kind: headerLong)
