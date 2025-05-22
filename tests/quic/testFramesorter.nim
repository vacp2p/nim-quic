import unittest
import quic/transport/framesorter
import quic/errors
import std/[options, tables]
import chronos

proc allData(q: AsyncQueue[seq[byte]]): seq[byte] =
  var data: seq[byte]
  while q.len > 0:
    data.add(waitFor(q.get()))
  return data

suite "FrameSorter tests":
  test "insert single chunk no FIN":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(0, @[1'u8, 2, 3], false)
    check fs.emitPos == 3
    check fs.buffer.len == 0
    let emitted = allData(q)
    check emitted == @[1'u8, 2, 3]
    check not fs.isEOF()

  test "insert chunks before chunk at offset 0 has been received":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(1, @[2'u8], false)
    fs.insert(3, @[4'u8], false)

    check fs.emitPos == 0
    check fs.buffer.len == 2
    check q.len == 0
    check not fs.isEOF()

  test "insert chunk with FIN":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(0, @[1'u8, 2, 3], true)
    check fs.totalBytes.get() == 2
    check fs.isEOF()

  test "chunks inserted out of order are emitted in correct order":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(1, @[2'u8, 3, 4], false)
    fs.insert(4, @[5'u8, 6], true)
    fs.insert(0, @[1'u8], false)

    check fs.emitPos == 6
    check fs.buffer.len == 0
    let emitted = allData(q)
    check emitted == @[1'u8, 2, 3, 4, 5, 6]
    check fs.isEOF()

  test "chunks are read correctly":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(0, @[1'u8, 2, 3], false)

    check fs.emitPos == 3
    check fs.buffer.len == 0
    var emitted = allData(q)
    check emitted == @[1'u8, 2, 3]

    fs.insert(9, @[10'u8, 11, 12], false)

    fs.insert(3, @[4'u8, 5, 6], false)

    check fs.emitPos == 6
    check fs.buffer.len == 3 # [10, 11, 12] are not emitted yet
    emitted = allData(q)
    check emitted == @[4'u8, 5, 6]

  test "chunks received after fin are ignored":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(1, @[2'u8, 3, 4], true)
    fs.insert(4, @[5'u8, 6, 7], false)
    fs.insert(2, @[3'u8, 4, 5], false)
    fs.insert(0, @[1'u8], false)

    check fs.emitPos == 4
    check fs.buffer.len == 0
    var emitted = allData(q)
    check emitted == @[1'u8, 2, 3, 4]

  test "insert overlapping identical chunk":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(0, @[1'u8, 2, 3], false)
    fs.insert(1, @[2'u8, 3], false) # identical bytes, should not raise
    check fs.emitPos == 3
    var emitted = allData(q)
    check emitted == @[1'u8, 2, 3]

  test "insert overlapping conflicting chunk":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(1, @[2'u8, 3, 4], false)
    expect QuicError:
      fs.insert(2, @[9'u8, 3], false)

  test "detect complete stream":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(0, @[1'u8, 2, 3], false)
    fs.insert(3, @[4'u8, 5], true)
    check fs.isComplete()

  test "detect incomplete stream with gap":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(0, @[1'u8, 2, 3], false)
    fs.insert(4, @[5'u8], true)

    check not fs.isComplete()

  test "reset":
    var q = newAsyncQueue[seq[byte]]()
    var fs = initFrameSorter(q)

    fs.insert(0, @[1'u8, 2, 3], true)
    check fs.totalBytes.isSome
    fs.reset()
    check fs.totalBytes.isNone
    check fs.emitPos == 0
    check fs.buffer.len == 0
