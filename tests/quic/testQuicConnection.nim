import pkg/asynctest
import pkg/chronos
import pkg/quic/transport/quicconnection
import pkg/quic/transport/quicclientserver
import pkg/quic/udp/datagram
import pkg/quic/transport/connectionid
import ../helpers/simulation
import ../helpers/addresses

suite "quic connection":

  test "sends outgoing datagrams":
    let client = newQuicClientConnection(zeroAddress, zeroAddress)
    defer: await client.drop()
    client.send()
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  test "processes received datagrams":
    let client = newQuicClientConnection(zeroAddress, zeroAddress)
    defer: await client.drop()

    client.send()
    let datagram = await client.outgoing.get()

    let server = newQuicServerConnection(zeroAddress, zeroAddress, datagram)
    defer: await server.drop()

    server.receive(datagram)

  test "raises error when datagram that starts server connection is invalid":
    let invalid = Datagram(data: @[0'u8])

    expect IOError:
      discard newQuicServerConnection(zeroAddress, zeroAddress, invalid)

  test "performs handshake":
    let (client, server) = await performHandshake()
    defer: await client.drop()
    defer: await server.drop()

    check client.handshake.isSet()
    check server.handshake.isSet()

  test "performs handshake multiple times":
    for i in 1..100:
      let (client, server) = await performHandshake()
      await client.drop()
      await server.drop()

  test "returns the current connection ids":
    let (client, server) = await setupConnection()
    check server.ids.len > 0
    check client.ids.len > 0
    check server.ids != client.ids

  test "notifies about id changes":
    let (client, server) = await setupConnection()
    defer: await client.drop
    defer: await server.drop

    var newId: ConnectionId
    server.onNewId = proc (id: ConnectionId) =
      newId = id

    let simulation = simulateNetwork(client, server)
    defer: await simulation.cancelAndWait()

    await server.handshake.wait()
    check newId != ConnectionId.default

  test "raises ConnectionError when closed":
    let connection = newQuicClientConnection(zeroAddress, zeroAddress)
    await connection.drop()

    expect ConnectionError:
      connection.send()

    expect ConnectionError:
      connection.receive(Datagram(data: @[]))

    expect ConnectionError:
      discard await connection.openStream()

  test "has empty list of ids when closed":
    let connection = newQuicClientConnection(zeroAddress, zeroAddress)
    await connection.drop()

    check connection.ids.len == 0
