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

suite "streams":
  setup:
    var (client, server) = waitFor performHandshake()

  teardown:
    waitFor client.drop()
    waitFor server.drop()

  asyncTest "opens uni-directional streams":
    let stream1, stream2 = await client.openStream(unidirectional = true)
    check stream1 != stream2
    check stream1.isUnidirectional
    check stream2.isUnidirectional

  asyncTest "opens bi-directional streams":
    let stream1, stream2 = await client.openStream()
    check stream1 != stream2
    check not stream1.isUnidirectional
    check not stream2.isUnidirectional

  asyncTest "closes stream":
    let stream = await client.openStream()
    await stream.close()

  asyncTest "writes zero-length message":
    let stream = await client.openStream()
    await stream.write(@[])
    let datagram = await client.outgoing.get()

    check datagram.len > 0

  asyncTest "raises when writing to closed stream":
    let stream = await client.openStream()
    await stream.close()

    expect QuicError:
      await stream.write(@[1'u8, 2'u8, 3'u8])

  asyncTest "raises when reading from or writing to reset stream":
    let stream = await client.openStream()
    stream.reset()
    expect QuicError:
      discard await stream.read()

    expect QuicError:
      await stream.write(@[1'u8, 2'u8, 3'u8])

  asyncTest "accepts incoming streams":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[])

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    await simulation.cancelAndWait()

  asyncTest "reads from stream":
    let simulation = simulateNetwork(client, server)
    let message = @[1'u8, 2'u8, 3'u8]

    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    let incoming = await serverStream.read()
    check incoming == message

    await simulation.cancelAndWait()

  asyncTest "writes long messages to stream":
    let simulation = simulateNetwork(client, server)

    let stream = await client.openStream()
    let message = repeat(42'u8, 100 * sizeof(Ngtcp2Connection.buffer))
    asyncSpawn stream.write(message)

    let incoming = await server.incomingStream()
    for _ in 0 ..< 100:
      discard await incoming.read()

    await simulation.cancelAndWait()

  asyncTest "halts sender until receiver has caught up":
    let simulation = simulateNetwork(client, server)
    let message = repeat(42'u8, sizeof(Ngtcp2Connection.buffer))

    # send until blocked
    let sender = await client.openStream()
    while true:
      if not await sender.write(message).withTimeout(100.milliseconds):
        break

    # receive until blocked
    let receiver = await server.incomingStream()
    while true:
      if not await receiver.read().withTimeout(100.milliseconds):
        break

    # check that sender is unblocked
    check await sender.write(message).withTimeout(100.milliseconds)

    await simulation.cancelAndWait()

  asyncTest "handles packet loss":
    let simulation = simulateLossyNetwork(client, server)

    let message = @[1'u8, 2'u8, 3'u8]
    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    let incoming = await serverStream.read()

    check incoming == message

    await simulation.cancelAndWait()

  asyncTest "stream behavior when peer closes":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[1'u8, 2'u8, 3'u8])

    let serverStream = await server.incomingStream()

    discard await serverStream.read()

    await clientStream.close()

    await sleepAsync(100.milliseconds) # wait for stream to be closed

    # Reading from a closed stream should return EOF, not throw exception
    let eof = await serverStream.read()
    check eof.len == 0 # Should return EOF (empty array)

    # In QUIC, receiving FIN doesn't prevent writing back (half-close semantics)
    # Writing should still work unless the local side is closed
    await serverStream.write(@[4'u8, 5'u8, 6'u8])

    # But after we close our side, writing should fail
    await serverStream.close()
    expect QuicError:
      await serverStream.write(@[7'u8, 8'u8, 9'u8])

    await simulation.cancelAndWait()

  asyncTest "closes stream when underlying connection is closed by peer":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[1'u8, 2'u8, 3'u8])

    let serverStream = await server.incomingStream()
    discard await serverStream.read()

    await client.close()
    await sleepAsync(100.milliseconds) # wait for connection to be closed

    check serverStream.isClosed

    await simulation.cancelAndWait()

  asyncTest "reads last bytes from stream that is closed by peer":
    let simulation = simulateNetwork(client, server)
    let message = @[1'u8, 2'u8, 3'u8]

    let clientStream = await client.openStream()
    await clientStream.write(message)
    await clientStream.close()
    await sleepAsync(100.milliseconds) # wait for stream to be closed

    let serverStream = await server.incomingStream()
    let incoming = await serverStream.read()
    check incoming == message

    await simulation.cancelAndWait()

  asyncTest "closeWrite() prevents further writes":
    let simulation = simulateNetwork(client, server)
    let message = @[1'u8, 2'u8, 3'u8]

    let clientStream = await client.openStream()
    await clientStream.write(message)
    await clientStream.closeWrite()

    # Writing after closeWrite should fail
    expect QuicError:
      await clientStream.write(@[4'u8, 5'u8, 6'u8])

    await simulation.cancelAndWait()

  asyncTest "closeWrite() sends FIN but allows server to write back":
    let simulation = simulateNetwork(client, server)
    let clientMessage = @[1'u8, 2'u8, 3'u8]
    let serverMessage = @[4'u8, 5'u8, 6'u8]

    # Client writes and closes write side
    let clientStream = await client.openStream()
    await clientStream.write(clientMessage)
    await clientStream.closeWrite()

    # Server reads client message
    let serverStream = await server.incomingStream()
    let incoming = await serverStream.read()
    check incoming == clientMessage

    # Server should still be able to write back
    await serverStream.write(serverMessage)

    # Client should be able to read server's response
    let response = await clientStream.read()
    check response == serverMessage

    await simulation.cancelAndWait()

  asyncTest "closeWrite() called on closed stream does nothing":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.close()

    # Calling closeWrite on already closed stream should not raise
    await clientStream.closeWrite()
    await simulation.cancelAndWait()

  asyncTest "writing on a stream closed for writing raises error":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[1'u8, 2'u8, 3'u8])
    await clientStream.close()

    expect QuicError:
      await clientStream.write(@[4'u8, 5'u8, 6'u8])

    await simulation.cancelAndWait()

  asyncTest "empty write + closeWrite pattern works":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[])
    await clientStream.closeWrite()

    await simulation.cancelAndWait()

  asyncTest "empty write + data + closeWrite (libp2p pattern) works":
    let simulation = simulateNetwork(client, server)
    var uploadData = @[1'u8, 2'u8, 3'u8, 4'u8, 5'u8]

    let clientStream = await client.openStream()
    await clientStream.write(@[])
    await clientStream.write(uploadData)
    await clientStream.closeWrite()

    let serverStream = await server.incomingStream()
    let received = await serverStream.read()
    check received == uploadData

    await simulation.cancelAndWait()

  asyncTest "multiple empty writes before closeWrite works":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[])
    await clientStream.write(@[])
    await clientStream.closeWrite()

    await simulation.cancelAndWait()

  asyncTest "closeWrite immediately after openStream works":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.closeWrite()

    await simulation.cancelAndWait()

  asyncTest "perf-like upload/download pattern works":
    let simulation = simulateNetwork(client, server)
    var uploadData = @[6'u8, 7'u8, 8'u8, 9'u8, 10'u8]

    let clientStream = await client.openStream()
    await clientStream.write(@[])
    await clientStream.write(uploadData)
    await clientStream.closeWrite()

    let serverStream = await server.incomingStream()
    let received = await serverStream.read()
    check received == uploadData

    # Server sends response back
    var downloadData = @[11'u8, 12'u8, 13'u8, 14'u8, 15'u8]
    await serverStream.write(downloadData)
    await serverStream.closeWrite()

    let response = await clientStream.read()
    check response == downloadData

    await simulation.cancelAndWait()

  asyncTest "large data transfers with empty write activation work":
    let simulation = simulateNetwork(client, server)
    var largeData = newSeq[uint8](1000)
    for i in 0 ..< 1000:
      largeData[i] = uint8(i mod 256)

    let clientStream = await client.openStream()
    await clientStream.write(@[])
    await clientStream.write(largeData)
    await clientStream.closeWrite()

    let serverStream = await server.incomingStream()
    let received = await serverStream.read()
    check received == largeData

    await simulation.cancelAndWait()

  asyncTest "multiple data chunks after empty write activation work":
    let simulation = simulateNetwork(client, server)
    var chunk1 = @[20'u8, 21'u8, 22'u8]
    var chunk2 = @[23'u8, 24'u8, 25'u8]
    var chunk3 = @[26'u8, 27'u8, 28'u8]

    let clientStream = await client.openStream()
    await clientStream.write(@[])
    await clientStream.write(chunk1)
    await clientStream.write(chunk2)
    await clientStream.write(chunk3)
    await clientStream.closeWrite()

    let serverStream = await server.incomingStream()
    var allReceived: seq[uint8]

    # Read all chunks
    let received1 = await serverStream.read()
    allReceived.add(received1)

    try:
      let received2 = await serverStream.read()
      allReceived.add(received2)
      let received3 = await serverStream.read()
      allReceived.add(received3)
    except:
      # May receive combined chunks due to TCP-like behavior
      discard

    var expectedData = chunk1 & chunk2 & chunk3
    check allReceived == expectedData

    await simulation.cancelAndWait()

  asyncTest "read() returns EOF after closeWrite()":
    let simulation = simulateNetwork(client, server)
    let testData = @[1'u8, 2'u8, 3'u8, 4'u8, 5'u8]

    # Client writes data and closes write side
    let clientStream = await client.openStream()
    await clientStream.write(testData)
    await clientStream.closeWrite()

    # Server reads data
    let serverStream = await server.incomingStream()
    let received = await serverStream.read()
    check received == testData

    # Second read should return EOF (empty array)
    let eof = await serverStream.read()
    check eof.len == 0 # EOF should be empty array

    # Third read should also return EOF
    let eof2 = await serverStream.read()
    check eof2.len == 0 # Multiple EOF reads should work

    await simulation.cancelAndWait()

  asyncTest "request-response pattern with half-close":
    let simulation = simulateNetwork(client, server)
    let request = cast[seq[byte]]("GET /\n")
    let response = cast[seq[byte]]("HTTP/1.1 200 OK\n")

    # Client sends request and closes write side (signals end of request)
    let clientStream = await client.openStream()
    await clientStream.write(request)
    await clientStream.closeWrite() # "I'm done sending the request"

    # Server receives the request  
    let serverStream = await server.incomingStream()
    let receivedRequest = await serverStream.read()
    check receivedRequest == request

    # Server detects end of request (EOF)
    let requestEof = await serverStream.read()
    check requestEof.len == 0 # End of request

    # Server processes and sends response (can still write back!)
    await serverStream.write(response)
    await serverStream.close() # Server finishes and closes completely

    # Client reads the response
    let receivedResponse = await clientStream.read()
    check receivedResponse == response

    # Client detects end of response
    let responseEof = await clientStream.read()
    check responseEof.len == 0 # End of response

    # At this point both sides have received what they need
    # Client can't write (closeWrite called), server can't write (close called)
    expect QuicError:
      await clientStream.write(@[ord('X').uint8])
        # Should fail - client closed write side

    await simulation.cancelAndWait()
