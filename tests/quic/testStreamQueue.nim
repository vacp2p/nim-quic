import std/[options]
import unittest
import chronos
import quic/transport/ngtcp2/streamstate/queue

proc allData(q: AsyncQueue[seq[byte]]): seq[byte] =
  var data: seq[byte]
  while q.len > 0:
    data.add(waitFor(q.get()))
  return data

suite "StreamQueue tests":
  test "insert single chunk no FIN":
    var fs = initStreamQueue()

    fs.insert(0, @[1'u8, 2, 3], false)
    check fs.emitPos == 3
    check allData(fs.incoming) == @[1'u8, 2, 3]
    check not fs.isEOF()

  test "insert chunk with FIN":
    var fs = initStreamQueue()

    fs.insert(0, @[1'u8, 2, 3], true)
    check fs.totalBytes.get() == 2
    check fs.isEOF()

  test "chunks inserted out of order are emitted in correct order":
    var fs = initStreamQueue()

    fs.insert(0, @[1'u8], false)
    fs.insert(1, @[2'u8, 3, 4], false)
    fs.insert(4, @[5'u8, 6], true)

    check fs.emitPos == 6
    check allData(fs.incoming) == @[1'u8, 2, 3, 4, 5, 6]
    check fs.isEOF()

  test "chunks are read correctly":
    var fs = initStreamQueue()

    fs.insert(0, @[1'u8, 2, 3], false)

    check fs.emitPos == 3
    check allData(fs.incoming) == @[1'u8, 2, 3]

    fs.insert(3, @[4'u8, 5, 6], false)
    fs.insert(9, @[10'u8, 11, 12], false)

    check fs.emitPos == 9
    check allData(fs.incoming) == @[4'u8, 5, 6, 10, 11, 12]

  test "reset":
    var fs = initStreamQueue()

    fs.insert(0, @[1'u8, 2, 3], true)
    check fs.totalBytes.isSome
    fs.reset()
    check fs.totalBytes.isNone
    check fs.emitPos == 0
