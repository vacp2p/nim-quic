import unittest2
import std/deques
import pkg/quic/transport/ngtcp2/native/pendingackqueue

suite "pending ack queue":
  test "empty queue at init":
    var q = PendingAckQueue.new()
    check:
      q.isEmpty()
      q.ackedNext == 0

  test "push ignores empty payload":
    var q = PendingAckQueue.new()
    q.push(@[])
    check:
      q.isEmpty()
      q.ackedNext == 0

  test "push sets offsets cumulatively":
    var q = PendingAckQueue.new()
    q.push(newSeq[byte](3))
    check:
      q.isEmpty() == false
      q.buffers.len == 1
      q.buffers.peekFirst.offset == 0
      q.buffers.peekFirst.endPos == 2

    q.push(newSeq[byte](2))
    check:
      q.buffers.len == 2
      q.buffers.peekLast.offset == 3
      q.buffers.peekLast.endPos == 4

  test "ack with length==0 is no-op":
    var q = PendingAckQueue.new()
    q.push(newSeq[byte](4))
    q.ack(0, 0)
    check:
      q.ackedNext == 0
      q.buffers.len == 1

  test "ack behavior":
    var q = PendingAckQueue.new()
    q.push(newSeq[byte](3))
    q.push(newSeq[byte](2))

    q.ack(0, 2) # partial into first
    check:
      q.ackedNext == 2
      q.buffers.len == 2 # nothing popped yet
      q.buffers.peekFirst.endPos == 2

    q.ack(0, 1) # <= current ack = no-op
    check:
      q.ackedNext == 2
      q.buffers.len == 2

    q.ack(2, 1) # first completes, should pop
    check:
      q.ackedNext == 3
      q.buffers.len == 1
      q.buffers.peekFirst.offset == 3
      q.buffers.peekFirst.endPos == 4

  test "ack beyond current head consumes multiple buffers":
    var q = PendingAckQueue.new()
    q.push(newSeq[byte](3))
    q.push(newSeq[byte](4))
    q.push(newSeq[byte](5))

    q.ack(0, 8)
    check:
      q.ackedNext == 8
      # buffers with endPos <= 7 should be popped
      q.buffers.len == 1
      q.buffers.peekFirst.offset == 7
      q.buffers.peekFirst.endPos == 11

  test "pushing after partial ack uses last.endPos for next offset":
    var q = PendingAckQueue.new()
    q.push(newSeq[byte](3))
    q.push(newSeq[byte](2))

    q.ack(0, 4) # pop first, partial into second 
    check q.ackedNext == 4
    check q.buffers.len == 1
    check q.buffers.peekFirst.offset == 3
    check q.buffers.peekFirst.endPos == 4

    q.push(newSeq[byte](4)) # new buffer offset should be last.endPos
    check:
      q.buffers.len == 2
      q.buffers.peekLast.offset == 5
      q.buffers.peekLast.endPos == 8

  test "full drain":
    var q = PendingAckQueue.new()
    q.push(newSeq[byte](1))
    q.push(newSeq[byte](1))
    q.push(newSeq[byte](1))
    check q.buffers.len == 3

    q.ack(0, 3)
    check:
      q.ackedNext == 3
      q.isEmpty()
      q.buffers.len == 0

  test "ensure pointers are not affected by queue ops":
    var q = PendingAckQueue.new()
    let seq1 = newSeq[byte](2)
    let seq2 = newSeq[byte](3)
    let seq3 = newSeq[byte](4)

    let seq1ptr = seq1[0].addr
    let seq2ptr = seq2[0].addr
    let seq3ptr = seq3[0].addr

    q.push(seq1)
    q.push(seq2)
    q.push(seq3)

    check:
      q.buffers[0].data[0].addr == seq1ptr
      q.buffers[1].data[0].addr == seq2ptr
      q.buffers[2].data[0].addr == seq3ptr

    q.ack(0, 2)

    check:
      q.buffers[0].data[0].addr == seq2ptr
      q.buffers[1].data[0].addr == seq3ptr
