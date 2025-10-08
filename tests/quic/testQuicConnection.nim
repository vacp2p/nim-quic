import chronos
import chronos/unittest2/asynctests
import quic/errors
import std/sets
import quic/helpers/rand
import quic/transport/[quicconnection, quicclientserver, tlsbackend]
import quic/udp/datagram
import quic/transport/connectionid
import ../helpers/simulation
import ../helpers/addresses
import ../helpers/certificate

suite "quic connection":
  asyncTest "sends outgoing datagrams":
    let clientTLSBackend =
      newClientTLSBackend(@[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier))
    let client =
      newQuicClientConnection(clientTLSBackend, zeroAddress, zeroAddress, newRng())
    defer:
      await client.drop()
    client.send()
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asyncTest "processes received datagrams":
    let rng = newRng()
    let clientTLSBackend =
      newClientTLSBackend(@[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier))
    let client =
      newQuicClientConnection(clientTLSBackend, zeroAddress, zeroAddress, rng)
    defer:
      await client.drop()

    client.send()
    let datagram = await client.outgoing.get()

    let serverTLSBackend =
      newServerTLSBackend(@[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier))
    let server =
      newQuicServerConnection(serverTLSBackend, zeroAddress, zeroAddress, datagram, rng)
    defer:
      await server.drop()

    server.receive(datagram)

  asyncTest "raises error when datagram that starts server connection is invalid":
    let invalid = Datagram(data: @[0'u8])

    expect QuicError:
      let serverTLSBackend = newServerTLSBackend(
        @[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier)
      )
      discard newQuicServerConnection(
        serverTLSBackend, zeroAddress, zeroAddress, invalid, newRng()
      )

  asyncTest "performs handshake":
    for i in 1 .. 10:
      let (client, server) = await performHandshake()
      check client.handshake.isSet()
      check server.handshake.isSet()
      await client.drop()
      await server.drop()

  asyncTest "returns the current connection ids":
    let (client, server) = await setupConnection()
    check server.ids.len > 0
    check client.ids.len > 0
    check server.ids != client.ids

  asyncTest "notifies about id changes":
    let rng = newRng()
    let clientTLSBackend =
      newClientTLSBackend(@[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier))
    let client =
      newQuicClientConnection(clientTLSBackend, zeroAddress, zeroAddress, rng)
    client.send()
    let datagram = await client.outgoing.get()

    let serverTLSBackend = newServerTLSBackend(
      testCertificate(),
      testPrivateKey(),
      toHashSet(["test"]),
      Opt.none(CertificateVerifier),
    )
    let server =
      newQuicServerConnection(serverTLSBackend, zeroAddress, zeroAddress, datagram, rng)
    var newId: ConnectionId
    server.onNewId = proc(id: ConnectionId) =
      newId = id
    server.receive(datagram)

    let simulation = simulateNetwork(client, server)

    await server.handshake.wait()
    check newId != ConnectionId.default

    await simulation.cancelAndWait()
    await client.drop
    await server.drop

  asyncTest "raises ConnectionError when closed":
    let clientTLSBackend =
      newClientTLSBackend(@[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier))
    let connection =
      newQuicClientConnection(clientTLSBackend, zeroAddress, zeroAddress, newRng())
    await connection.drop()

    expect ConnectionError:
      connection.send()

    expect ConnectionError:
      discard await connection.openStream()

  asyncTest "has empty list of ids when closed":
    let clientTLSBackend =
      newClientTLSBackend(@[], @[], toHashSet(["test"]), Opt.none(CertificateVerifier))
    let connection =
      newQuicClientConnection(clientTLSBackend, zeroAddress, zeroAddress, newRng())
    await connection.drop()

    check connection.ids.len == 0
