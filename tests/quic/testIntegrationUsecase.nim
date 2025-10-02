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

      let connection = await listener.accept()
      check connection.certificates().len == 1

      let stream = await connection.incomingStream()
      let receivedData = await readStreamTillEOF(stream)
      checkEqual(message, receivedData)

      await stream.close()
      await connection.close()
      await listener.stop()
      listener.destroy()

    waitFor allSucceeded(incoming(), outgoing())

  asyncTest "connect many clients to single server":
    const count = 2 # should be increased when bug is fixed
    let serverDone = newWaitGroup(count)
    let clientDone = newWaitGroup(count)
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    let message = newData(50 * 1024)

    proc handleConn(connection: Connection) {.async.} =
      let stream = await connection.incomingStream()
      let receivedData = await readStreamTillEOF(stream)
      checkEqual(message, receivedData)

      await stream.close()
      await connection.close()
      serverDone.done()

    proc runClient() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)

      let stream = await connection.openStream()
      await stream.write(message)
      await stream.close()
      await connection.close()

      clientDone.done()

    for i in 0 ..< count:
      asyncSpawn runClient()

    asyncSpawn accept(listener, handleConn)
    waitFor allSucceeded(serverDone.wait(), clientDone.wait())
    await listener.stop()
    listener.destroy()

  asyncTest "incomingStream returns error when client disconnects":
    const count = 20
    let serverDone = newWaitGroup(count)
    let clientDone = newWaitGroup(count)
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    let message = newData(50 * 1024)

    proc handleConn(connection: Connection) {.async.} =
      try:
        let stream = await connection.incomingStream()
        doAssert false, "should not open stream"
      except QuicError as e:
        discard

      await connection.close()
      serverDone.done()

    proc runClient() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)
      # after dial client closes connection, without opening stream
      await connection.close()
      clientDone.done()

    for i in 0 ..< count:
      asyncSpawn runClient()

    asyncSpawn accept(listener, handleConn)
    waitFor allSucceeded(serverDone.wait(), clientDone.wait())
    await listener.stop()
    listener.destroy()

  asyncTest "openStream returns error when server disconnects":
    const count = 20
    let serverDone = newWaitGroup(count)
    let clientDone = newWaitGroup(count)
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    let message = newData(50 * 1024)

    proc handleConn(connection: Connection) {.async.} =
      await connection.close()
      serverDone.done()

    proc runClient() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)

      # wait for server to disconnect
      await serverDone.wait()
      try:
        let stream = await connection.openStream()
        doAssert false, "should not open stream"
      except QuicError as e:
        discard

      await connection.close()
      clientDone.done()

    for i in 0 ..< count:
      asyncSpawn runClient()

    asyncSpawn accept(listener, handleConn)
    waitFor allSucceeded(serverDone.wait(), clientDone.wait())
    await listener.stop()
    listener.destroy()
