import std/unittest
import std/sequtils
import chronos
import quic
import ../helpers/asynctest
import ../helpers/connections
import ../helpers/addresses
import ../helpers/contains

suite "streams":

  var client {.threadvar.}: Connection
  var server {.threadvar.}: Connection

  asyncsetup:
    (client, server) = await performHandshake()

  asynctest "opens uni-directional streams":
    check client.openStream() != client.openStream()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()

  asynctest "closes stream":
    let stream = client.openStream()
    stream.close()

  asynctest "writes to stream":
    let stream = client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    await stream.write(message)
    let datagram = await client.outgoing.get()
    check datagram.data.contains(message)

  asynctest "writes zero-length message":
    let stream = client.openStream()
    await stream.write(@[])
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asynctest "raises when stream could not be written to":
    let stream = client.openStream()
    stream.close()

    expect IOError:
      await stream.write(@[1'u8, 2'u8, 3'u8])

  asynctest "writes long messages to stream":
    let messageCounter = Counter()
    let simulation = simulateNetwork(client, server, messageCounter)
    defer: simulation.cancel()

    let stream = client.openStream()
    let message = repeat(42'u8, 100 * sizeof(client.buffer))
    await stream.write(message)

    check messageCounter.count > 100

  asynctest "accepts incoming streams":
    let simulation = simulateNetwork(client, server)
    defer: simulation.cancel()

    let clientStream = client.openStream()
    await clientStream.write(@[])

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

  asynctest "reads from stream":
    let simulation = simulateNetwork(client, server)
    defer: simulation.cancel()

    let message = @[1'u8, 2'u8, 3'u8]
    await client.openStream().write(message)

    let stream = await server.incomingStream()
    let incoming = await stream.read()

    check incoming == message
