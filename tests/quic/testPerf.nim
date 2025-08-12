import std/sequtils
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic/errors
import pkg/quic/transport/stream
import pkg/quic/transport/quicconnection
import pkg/quic/transport/ngtcp2/native
import pkg/quic/udp/datagram
import tests/helpers/simulation

suite "perf protocol like test":
  setup:
    var (client, server) = waitFor performHandshake()

  teardown:
    waitFor client.drop()
    waitFor server.drop()

  asyncTest "perf protocol simulation":
    # This test simulates the exact perf protocol flow:
    # 1. Client sends 8 bytes (download size)
    # 2. Client sends upload data (100KB)
    # 3. Client calls closeWrite() 
    # 4. Server reads all data including the closeWrite signal (should get EOF)
    # 5. Server sends download data back

    let simulation = simulateNetwork(client, server)
    let clientStream = await client.openStream()

    const
      uploadSize = 100000 # 100KB like in perf test
      downloadSize = 10000000 # 10MB like in perf test
      chunkSize = 65536 # 64KB chunks like perf

    proc serverHandler() {.async.} =
      let serverStream = await server.incomingStream()

      # Step 1: Read download size (8 bytes) 
      let sizeData = await serverStream.read()
      # In real perf this would be parsed as uint64, but we skip that

      # Step 2: Read upload data until EOF
      var totalBytesRead = 0
      while true:
        let chunk = await serverStream.read()
        if chunk.len == 0:
          break
        totalBytesRead += chunk.len

      # Step 3: Send download data back
      var remainingToSend = downloadSize
      while remainingToSend > 0:
        let toSend = min(remainingToSend, chunkSize)
        await serverStream.write(newSeq[byte](toSend))
        remainingToSend -= toSend

      await serverStream.close()

    # Start server handler
    asyncSpawn serverHandler()

    # Step 1: Send download size (8 bytes) - activate stream first
    await clientStream.write(@[0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 152'u8, 150'u8, 128'u8])
      # 10MB in big endian

    # Step 2: Send upload data in chunks
    var remainingToSend = uploadSize
    while remainingToSend > 0:
      let toSend = min(remainingToSend, chunkSize)
      let dummyData = newSeq[byte](toSend)
      await clientStream.write(dummyData)
      remainingToSend -= toSend

    # Step 3: Close write side (this is where the problem happens)
    await clientStream.closeWrite()

    # Step 4: Start reading download data
    var totalDownloaded = 0
    while totalDownloaded < downloadSize:
      let chunk = await clientStream.read()
      totalDownloaded += chunk.len

    await clientStream.close()
    await simulation.cancelAndWait()
