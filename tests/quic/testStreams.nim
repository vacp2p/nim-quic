import std/sequtils
import pkg/asynctest
import pkg/chronos
import pkg/quic/transport/stream
import pkg/quic/transport/quicconnection
import pkg/quic/transport/ngtcp2
import pkg/quic/udp/datagram
import ../helpers/simulation
import ../helpers/contains

suite "streams":

  var client, server: QuicConnection

  setup:
    (client, server) = await performHandshake()

  teardown:
    await client.drop()
    await server.drop()

  test "opens uni-directional streams":
    check client.openStream() != client.openStream()

  test "closes stream":
    let stream = await client.openStream()
    await stream.close()

  test "writes to stream":
    let stream = await client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    await stream.write(message)

    check client.outgoing.anyIt(it.data.contains(message))

  test "writes zero-length message":
    let stream = await client.openStream()
    await stream.write(@[])
    let datagram = await client.outgoing.get()

    check datagram.len > 0

  test "raises when reading from or writing to closed stream":
    let stream = await client.openStream()
    await stream.close()

    expect IOError:
      discard await stream.read()

    expect IOError:
      await stream.write(@[1'u8, 2'u8, 3'u8])

  test "accepts incoming streams":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[])

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    await simulation.cancelAndWait()

  test "reads from stream":
    let simulation = simulateNetwork(client, server)
    let message = @[1'u8, 2'u8, 3'u8]

    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    let incoming = await serverStream.read()
    check incoming == message

    await simulation.cancelAndWait()

  test "writes long messages to stream":
    let simulation = simulateNetwork(client, server)

    let stream = await client.openStream()
    let message = repeat(42'u8, 100 * sizeof(Ngtcp2Connection.buffer))
    await stream.write(message)

    let incoming = await server.incomingStream()
    for _ in 0..<100:
      discard await incoming.read()

    await simulation.cancelAndWait()

  test "handles packet loss":
    let simulation = simulateLossyNetwork(client, server)

    let message = @[1'u8, 2'u8, 3'u8]
    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    let incoming = await serverStream.read()

    check incoming == message

    await simulation.cancelAndWait()

  test "raises when stream is closed by peer":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[1'u8, 2'u8, 3'u8])

    let serverStream = await server.incomingStream()
    discard await serverStream.read()

    await clientStream.close()
    await sleepAsync(100.milliseconds) # wait for stream to be closed

    expect IOError:
      discard await serverStream.read()

    expect IOError:
      await serverStream.write(@[1'u8, 2'u8, 3'u8])

    await simulation.cancelAndWait()

  test "reads last bytes from stream that is closed by peer":
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
