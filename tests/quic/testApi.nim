import chronos
import chronos/unittest2/asynctests
import quic
import ../helpers/certificate

suite "api":
  setup:
    let serverTLSConfig = TLSConfig.init(testCertificate(), testPrivateKey(), @["test"])
    var server = QuicServer.init(serverTLSConfig)
    let clientTLSConfig = TLSConfig.init(alpn = @["test"])
    var client = QuicClient.init(clientTLSConfig)
    var listener = server.listen(initTAddress("127.0.0.1:0"))
    let address = listener.localAddress

  teardown:
    waitFor listener.stop()

  asyncTest "opens and drops connections":
    let dialing = client.dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    check:
      outgoing.remoteAddress.port == address.port
      outgoing.localAddress.port == incoming.remoteAddress.port
      incoming.localAddress.port == address.port

    await outgoing.drop()
    await incoming.drop()

  asyncTest "opens and closes streams":
    let dialing = client.dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    let stream1 = await outgoing.openStream()
    let stream2 = await incoming.openStream()

    await stream1.close()
    await stream2.close()

    await outgoing.drop()
    await incoming.drop()

  asyncTest "waits until peer closes connection":
    let dialing = client.dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    await incoming.close()
    await outgoing.waitClosed()

  asyncTest "client connection closes while server is waiting on incoming stream":
    let dialing = client.dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    discard outgoing.close()
    expect QuicError:
      discard await incoming.incomingStream()

  asyncTest "client connection drops while server is waiting on incoming stream":
    # the same test as above  but connection is dropped
    let dialing = client.dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    discard outgoing.drop()
    expect QuicError:
      # will happen with some delay, after timeout is triggered
      discard await incoming.incomingStream()

  asyncTest "server connection closes while client is waiting on stream":
    skip() # TODO(nim-quic#145): test added but code needs to be fixed
    return

    let dialing = client.dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    discard incoming.close()
    expect QuicError:
      discard await outgoing.openStream()

  asyncTest "server connection drop while client is waiting on stream":
    skip() # TODO(nim-quic#145): test added but code needs to be fixed
    return

    let dialing = client.dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    discard incoming.drop()
    expect QuicError:
      discard await outgoing.openStream()

  asyncTest "accepts multiple incoming connections":
    let accepting1 = listener.accept()
    let outgoing1 = await client.dial(address)
    let incoming1 = await accepting1

    let accepting2 = listener.accept()
    let outgoing2 = await client.dial(address)
    let incoming2 = await accepting2

    check incoming1 != incoming2

    await outgoing1.drop()
    await outgoing2.drop()
    await incoming1.drop()
    await incoming2.drop()

  asyncTest "writes to and reads from streams":
    let message = @[1'u8, 2'u8, 3'u8]

    let outgoing = await client.dial(address)
    defer:
      await outgoing.drop()

    let incoming = await listener.accept()
    defer:
      await incoming.drop()

    let outgoingStream = await outgoing.openStream()
    defer:
      await outgoingStream.close()

    await outgoingStream.write(message)

    let incomingStream = await incoming.incomingStream()
    defer:
      await incomingStream.close()

    check (await incomingStream.read()) == message
