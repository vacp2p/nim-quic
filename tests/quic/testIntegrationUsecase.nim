import results
import pkg/unittest2
import pkg/quic
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import ../helpers/[async, stream, clientserver]

type handler = proc(connection: Connection): Future[void] {.gcsafe, raises: [].}

proc accept(listener: Listener, handleConn: handler) {.async.} =
  while true:
    let connection =
      try:
        await listener.accept()
      except CatchableError:
        return

    asyncSpawn handleConn(connection)

template deferStop(listener: Listener) =
  defer:
    await listener.stop()
    listener.destroy()

suite "Quic integration usecases":
  test "client to server send and receive message":
    let message = newData(50 * 1024)
    let address = initTAddress("127.0.0.1:12345")

    proc outgoing() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)
      check connection.certificates().len == 1

      let stream = await connection.openStream()
      await stream.write(message)
      await stream.close()
      await connection.close()

    proc incoming() {.async.} =
      let server = makeServer()
      let listener = server.listen(address)
      listener.deferStop()

      let connection = await listener.accept()
      check connection.certificates().len == 1

      let stream = await connection.incomingStream()
      let receivedData = await readStreamTillEOF(stream)
      checkEqual(message, receivedData)

      await stream.close()
      await connection.close()

    waitFor allFutures(incoming(), outgoing())

  asyncTest "connect many clients to single server":
    const connectionsCount = 20
    const msgSize = 50 * 1024
    let serverWg = newWaitGroup(connectionsCount)
    let clientWg = newWaitGroup(connectionsCount)
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    listener.deferStop()

    let message = newData(msgSize)

    proc handleServerConn(connection: Connection) {.async.} =
      let stream = await connection.incomingStream()
      let receivedData = await readStreamTillEOF(stream)
      checkEqual(message, receivedData)

      await stream.close()
      await connection.close()
      serverWg.done()

    proc runClient() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)

      let stream = await connection.openStream()
      await stream.write(message)
      await stream.close()

      # client needs to wait some time before closing connections. 
      # because if connection is closed too early data will not be transmitted to server.
      await sleepAsync(300.milliseconds)
      await connection.close()

      clientWg.done()

    asyncSpawn accept(listener, handleServerConn)
    for i in 0 ..< connectionsCount:
      asyncSpawn runClient()
    waitFor allFutures(serverWg.wait(), clientWg.wait())

  asyncTest "connections with many streams":
    const connectionsCount = 3
    const streamsCount = 20
    const msgSize = 50 * 1024
    let serverWg = newWaitGroup(connectionsCount)
    let clientWg = newWaitGroup(connectionsCount)
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    listener.deferStop()

    proc handleServerStream(connection: Connection, connWg: WaitGroup) {.async.} =
      let stream = await connection.incomingStream()
      let receivedData = await readStreamTillEOF(stream)
      let dataId = receivedData[0]
      checkEqual(newData(msgSize, dataId), receivedData)
      await stream.close()
      connWg.done()

    proc handleServerConn(connection: Connection) {.async.} =
      let connWg = newWaitGroup(streamsCount)
      for i in 0 ..< streamsCount:
        asyncSpawn handleServerStream(connection, connWg)

      await connWg.wait()
      await connection.close()
      serverWg.done()

    proc handleClientStream(
        connection: Connection, connWg: WaitGroup, id: uint8
    ) {.async.} =
      let stream = await connection.openStream()
      await stream.write(newData(msgSize, id)) # send data unique for this stream
      await stream.close()
      connWg.done()

    proc runClient() {.async.} =
      let connWg = newWaitGroup(streamsCount)
      let client = makeClient()
      let connection = await client.dial(address)

      for i in 0 ..< streamsCount:
        asyncSpawn handleClientStream(connection, connWg, i.uint8)

      await connWg.wait()
      await connection.close()
      clientWg.done()

    asyncSpawn accept(listener, handleServerConn)
    for i in 0 ..< connectionsCount:
      asyncSpawn runClient()
    waitFor allFutures(serverWg.wait(), clientWg.wait())

  asyncTest "incomingStream throws error when client disconnects":
    const connectionsCount = 20
    let serverWg = newWaitGroup(connectionsCount)
    let clientWg = newWaitGroup(connectionsCount)
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    listener.deferStop()

    proc handleServerConn(connection: Connection) {.async.} =
      expect QuicError:
        # should not be able to open stream as client has disconnected
        discard await connection.incomingStream()

      await connection.close()
      serverWg.done()

    proc runClient() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)
      # after dial client closes connection, without opening stream
      await connection.close()
      clientWg.done()

    asyncSpawn accept(listener, handleServerConn)
    for i in 0 ..< connectionsCount:
      asyncSpawn runClient()
    waitFor allFutures(serverWg.wait(), clientWg.wait())

  asyncTest "openStream throws error when server disconnects":
    const connectionsCount = 20
    let serverWg = newWaitGroup(connectionsCount)
    let clientWg = newWaitGroup(connectionsCount)
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    listener.deferStop()

    proc handleServerConn(connection: Connection) {.async.} =
      await connection.close()
      serverWg.done()

    proc runClient() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)

      # wait for server to disconnect
      await serverWg.wait()

      expect QuicError:
        # should not be able to open stream as server has disconnected
        discard await connection.openStream()

      await connection.close()
      clientWg.done()

    asyncSpawn accept(listener, handleServerConn)
    for i in 0 ..< connectionsCount:
      asyncSpawn runClient()
    waitFor allFutures(serverWg.wait(), clientWg.wait())
