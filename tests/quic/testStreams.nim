import std/unittest
import std/sequtils
import pkg/chronos
import pkg/quic
import ../helpers/asynctest
import ../helpers/simulation
import ../helpers/addresses
import ../helpers/contains

suite "streams":

  asynctest "opens uni-directional streams":
    let (client, server) = await performHandshake()
    check client.openStream() != client.openStream()

    client.destroy()
    server.destroy()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()

    client.destroy()

  asynctest "closes stream":
    let (client, server) = await performHandshake()
    let stream = client.openStream()

    stream.close()

    client.destroy()
    server.destroy()

  asynctest "writes to stream":
    let (client, server) = await performHandshake()
    let stream = client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    await stream.write(message)

    check client.outgoing.anyIt(it.data.contains(message))

    client.destroy()
    server.destroy()

  asynctest "writes zero-length message":
    let (client, server) = await performHandshake()
    let stream = client.openStream()
    await stream.write(@[])
    let datagram = await client.outgoing.get()

    check datagram.len > 0

    client.destroy()
    server.destroy()

  asynctest "raises when stream could not be written to":
    let (client, server) = await performHandshake()
    let stream = client.openStream()
    stream.close()

    expect IOError:
      await stream.write(@[1'u8, 2'u8, 3'u8])

    client.destroy()
    server.destroy()

  asynctest "writes long messages to stream":
    let (client, server) = await performHandshake()
    let messageCounter = Counter()
    let simulation = simulateNetwork(client, server, messageCounter)

    let stream = client.openStream()
    let message = repeat(42'u8, 100 * sizeof(client.buffer))
    await stream.write(message)

    check messageCounter.count > 100

    await simulation.cancelAndWait()
    client.destroy()
    server.destroy()

  asynctest "accepts incoming streams":
    let (client, server) = await performHandshake()
    let simulation = simulateNetwork(client, server)

    let clientStream = client.openStream()
    await clientStream.write(@[])

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    await simulation.cancelAndWait()
    client.destroy()
    server.destroy()

  asynctest "reads from stream":
    let (client, server) = await performHandshake()
    let simulation = simulateNetwork(client, server)

    let message = @[1'u8, 2'u8, 3'u8]
    await client.openStream().write(message)

    let stream = await server.incomingStream()
    let incoming = await stream.read()

    check incoming == message

    await simulation.cancelAndWait()
    client.destroy()
    server.destroy()

  asynctest "handles packet loss":
    let (client, server) = await performHandshake()
    let simulation = simulateLossyNetwork(client, server)

    let message = @[1'u8, 2'u8, 3'u8]
    await client.openStream().write(message)

    let stream = await server.incomingStream()
    let incoming = await stream.read()

    check incoming == message

    await simulation.cancelAndWait()
    client.destroy()
    server.destroy()
