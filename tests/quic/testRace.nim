import std/sequtils
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic/errors
import pkg/quic/transport/stream
import pkg/quic/transport/quicconnection
import pkg/quic/transport/ngtcp2/native
import pkg/quic/udp/datagram
import ../helpers/simulation
import ../helpers/contains

proc newData(size: int, val: uint8 = uint8(0xEE)): seq[uint8] =
  var data = newSeq[uint8](size)
  for i in 0 ..< size:
    data[i] = val
  return data

proc readStreamTillEOF(stream: Stream): Future[seq[uint8]] {.async.} =
  var receivedData: seq[uint8]
  var c: int
  while true:
    let chunk = await stream.read()
    if chunk.len == 0:
      break
    receivedData.add(chunk)
    c.inc

  return receivedData

suite "streams":
  asyncTest "test":
    const dataSize = (9 * 1024 * 1024) + 1 # 10 MB
    let testData = newData(dataSize, uint8(0xEE))

    for i in 0 ..< 2000:
      echo $i
      var (client, server) = waitFor performHandshake()
      let simulation = simulateNetwork(client, server)

      let clientStream = await client.openStream()
      await clientStream.write(@[]) # Activate stream
      let serverStream = await server.incomingStream()

      # Client starts writing first (non-blocking)
      let clientWriteTask = proc() {.async.} =
        await clientStream.write(testData)
        await clientStream.closeWrite()

      discard clientWriteTask()

      # Server starts reading in parallel (after client already started)
      let receivedData = await readStreamTillEOF(serverStream)

      # Verify data
      check receivedData == testData

      check (await serverStream.read()).len == 0

      await serverStream.close()
      await clientStream.close()
      await simulation.cancelAndWait()
      await client.drop()
      await server.drop()
