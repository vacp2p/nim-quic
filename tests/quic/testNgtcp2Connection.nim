import std/unittest
import pkg/chronos
import pkg/quic/transport/quicconnection
import pkg/quic/transport/quicclient
import pkg/quic/transport/quicserver
import pkg/quic/udp/datagram
import pkg/quic/transport/connectionid
import ../helpers/asynctest
import ../helpers/simulation
import ../helpers/addresses

suite "quic connection":

  asynctest "sends outgoing datagrams":
    let client = newQuicClientConnection(zeroAddress, zeroAddress)
    defer: client.drop()
    client.send()
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asynctest "processes received datagrams":
    let client = newQuicClientConnection(zeroAddress, zeroAddress)
    defer: client.drop()

    client.send()
    let datagram = await client.outgoing.get()

    let server = newQuicServerConnection(zeroAddress, zeroAddress, datagram)
    defer: server.drop()

    server.receive(datagram)

  test "raises error when datagram that starts server connection is invalid":
    let invalid = Datagram(data: @[0'u8])

    expect IOError:
      discard newQuicServerConnection(zeroAddress, zeroAddress, invalid)

  asynctest "performs handshake":
    let (client, server) = await performHandshake()
    defer: client.drop()
    defer: server.drop()

    check client.handshake.isSet()
    check server.handshake.isSet()

  asynctest "performs handshake multiple times":
    for i in 1..100:
      let (client, server) = await performHandshake()
      client.drop()
      server.drop()

  asynctest "returns the current connection ids":
    let (client, server) = await setupConnection()
    check server.ids.len > 0
    check client.ids.len > 0
    check server.ids != client.ids

  asynctest "notifies about id changes":
    let (client, server) = await setupConnection()
    defer: client.drop
    defer: server.drop

    var newId: ConnectionId
    server.onNewId = proc (id: ConnectionId) =
      newId = id

    let simulation = simulateNetwork(client, server)
    defer: await simulation.cancelAndWait()

    await server.handshake.wait()
    check newId != ConnectionId.default
