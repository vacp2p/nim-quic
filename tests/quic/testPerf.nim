import std/sequtils
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic/transport/stream
import pkg/quic/transport/quicconnection
import pkg/stew/endians2
import ../helpers/simulation

const
  runs = 1
  uploadSize = 100000 # 100KB
  downloadSize = 100000000 # 100MB
  chunkSize = 65536 # 64KB chunks like perf

proc runPerf(): Future[Duration] {.async.} =
  var (client, server) = waitFor performHandshake()
  defer:
    waitFor client.drop()
    waitFor server.drop()

  let simulation = simulateNetwork(client, server)

  # This test simulates the exact perf protocol flow:
  # 1. Client sends 8 bytes (download size)
  # 2. Client sends upload data (100KB)
  # 3. Client calls closeWrite() 
  # 4. Server reads all data including the closeWrite signal (should get EOF)
  # 5. Server sends download data back

  proc serverHandler() {.async.} =
    let serverStream = await server.incomingStream()

    # Step 1: Read download size (8 bytes) 
    let clientDownloadSize = await serverStream.read()

    # Step 2: Read upload data until EOF
    var totalBytesRead = 0
    while true:
      let chunk = await serverStream.read()
      if chunk.len == 0:
        break
      totalBytesRead += chunk.len

    # Step 3: Send download data back
    var remainingToSend = uint64.fromBytesBE(clientDownloadSize)
    while remainingToSend > 0:
      let toSend = min(remainingToSend, chunkSize)
      await serverStream.write(newSeq[byte](toSend))
      remainingToSend -= toSend

    await serverStream.close()

  # Start server handler
  asyncSpawn serverHandler()

  let startTime = Moment.now()

  # Step 1: Send download size, activate stream first
  let clientStream = await client.openStream()
  await clientStream.write(toSeq(downloadSize.uint64.toBytesBE()))

  # Step 2: Send upload data in chunks
  var remainingToSend = uploadSize
  while remainingToSend > 0:
    let toSend = min(remainingToSend, chunkSize)
    await clientStream.write(newSeq[byte](toSend))
    remainingToSend -= toSend

  # Step 3: Close write side
  await clientStream.closeWrite()

  # Step 4: Start reading download data
  var totalDownloaded = 0
  while totalDownloaded < downloadSize:
    let chunk = await clientStream.read()
    totalDownloaded += chunk.len

  let duration = Moment.now() - startTime

  await clientStream.close()
  await simulation.cancelAndWait()

  return duration

suite "perf protocol simulation":
  asyncTest "test":
    var total: Duration
    for i in 0 ..< runs:
      let duration = await runPerf()
      total += duration
      echo "\trun #" & $(i + 1) & " duration: " & $duration

    echo "\tavrg duration: " & $(total div runs)
