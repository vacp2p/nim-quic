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

  test "opens uni-directional streams":
    let (client, server) = await performHandshake()
    check client.openStream() != client.openStream()

    await client.drop()
    await server.drop()

  test "closes stream":
    let (client, server) = await performHandshake()
    let stream = await client.openStream()

    await stream.close()

    await client.drop()
    await server.drop()

  test "writes to stream":
    let (client, server) = await performHandshake()
    let stream = await client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    await stream.write(message)

    check client.outgoing.anyIt(it.data.contains(message))

    await client.drop()
    await server.drop()

  test "writes zero-length message":
    let (client, server) = await performHandshake()
    let stream = await client.openStream()
    await stream.write(@[])
    let datagram = await client.outgoing.get()

    check datagram.len > 0

    await client.drop()
    await server.drop()

  test "raises when reading from or writing to closed stream":
    let (client, server) = await performHandshake()
    let stream = await client.openStream()
    await stream.close()

    expect IOError:
      discard await stream.read()

    expect IOError:
      await stream.write(@[1'u8, 2'u8, 3'u8])

    await client.drop()
    await server.drop()

  test "accepts incoming streams":
    let (client, server) = await performHandshake()
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[])

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    await simulation.cancelAndWait()
    await client.drop()
    await server.drop()

  test "reads from stream":
    let (client, server) = await performHandshake()
    let simulation = simulateNetwork(client, server)
    let message = @[1'u8, 2'u8, 3'u8]

    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    let incoming = await serverStream.read()
    check incoming == message

    await simulation.cancelAndWait()
    await client.drop()
    await server.drop()

  test "writes long messages to stream":
    let (client, server) = await performHandshake()
    let simulation = simulateNetwork(client, server)

    let stream = await client.openStream()
    let message = repeat(42'u8, 100 * sizeof(Ngtcp2Connection.buffer))
    await stream.write(message)

    let incoming = await server.incomingStream()
    for _ in 0..<100:
      discard await incoming.read()

    await simulation.cancelAndWait()
    await client.drop()
    await server.drop()


  test "handles packet loss":
    let (client, server) = await performHandshake()
    let simulation = simulateLossyNetwork(client, server)

    let message = @[1'u8, 2'u8, 3'u8]
    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    let incoming = await serverStream.read()

    check incoming == message

    await simulation.cancelAndWait()
    await client.drop()
    await server.drop()
