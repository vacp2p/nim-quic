import std/sequtils
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic/errors
import pkg/quic/transport/stream
import pkg/quic/transport/quicconnection
import pkg/quic/transport/ngtcp2/native
import pkg/quic/udp/datagram
import tests/helpers/simulation

suite "perf protocol like test - half-close hang":
  setup:
    var (client, server) = waitFor performHandshake()

  teardown:
    waitFor client.drop()
    waitFor server.drop()

  asyncTest "perf protocol simulation hangs on read after closeWrite":
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
      echo "SERVER: Got incoming stream"

      # Step 1: Read download size (8 bytes) 
      echo "SERVER: Reading download size (8 bytes)"
      let sizeData = await serverStream.read()
      echo "SERVER: Read download size: ", sizeData.len, " bytes"
      # In real perf this would be parsed as uint64, but we skip that

      # Step 2: Read upload data until EOF
      echo "SERVER: Starting to read upload data"
      var totalBytesRead = 0
      while true:
        echo "SERVER: Waiting for next chunk..."
        let chunk = await serverStream.read() # THIS WILL HANG after closeWrite!
        echo "SERVER: Read chunk: ", chunk.len, " bytes"

        if chunk.len == 0:
          echo "SERVER: Got EOF, total read: ", totalBytesRead
          break

        totalBytesRead += chunk.len
        echo "SERVER: Total bytes read so far: ", totalBytesRead

        if totalBytesRead >= uploadSize:
          echo "SERVER: Read all expected upload data"
          break # Exit the reading loop once we have all expected data

      echo "SERVER: Starting to send download data"
      # Step 3: Send download data back
      var remainingToSend = downloadSize
      while remainingToSend > 0:
        let toSend = min(remainingToSend, chunkSize)
        let dummyData = newSeq[byte](toSend)
        echo "about to send"
        await serverStream.write(dummyData)
        remainingToSend -= toSend
        echo "SERVER: Sent ", toSend, " bytes, remaining: ", remainingToSend

      await serverStream.close()
      echo "SERVER: Done"

    # Start server handler
    asyncSpawn serverHandler()

    await clientStream.write(@[])

    # Step 1: Send download size (8 bytes) - activate stream first
    echo "CLIENT: Sending download size"
    await clientStream.write(@[0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 152'u8, 150'u8, 128'u8])
      # 10MB in big endian

    # Step 2: Send upload data in chunks
    echo "CLIENT: Starting upload of ", uploadSize, " bytes"
    var remainingToSend = uploadSize
    while remainingToSend > 0:
      let toSend = min(remainingToSend, chunkSize)
      let dummyData = newSeq[byte](toSend)
      await clientStream.write(dummyData)
      remainingToSend -= toSend
      echo "CLIENT: Sent ", toSend, " bytes, remaining: ", remainingToSend

    # Step 3: Close write side (this is where the problem happens)
    echo "CLIENT: Upload complete, closing write side"
    await clientStream.closeWrite()
    echo "CLIENT: Write side closed"

    # Step 4: Start reading download data
    echo "CLIENT: Starting to read download data"
    var totalDownloaded = 0
    while totalDownloaded < downloadSize:
      let chunk = await clientStream.read()
      totalDownloaded += chunk.len
      echo "CLIENT: Downloaded ", chunk.len, " bytes, total: ", totalDownloaded

    echo "CLIENT: Download complete"
    await clientStream.close()

    await simulation.cancelAndWait()
