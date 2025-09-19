import results
import pkg/unittest2
import pkg/quic
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import ../helpers/[async, stream, clientserver]

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
      await connection.waitClosed()
      await listener.stop()
      listener.destroy()

    waitFor allSucceeded(incoming(), outgoing())

  asyncTest "connect many clients to single server":
    let address = initTAddress("127.0.0.1:12345")
    let server = makeServer()
    let listener = server.listen(address)
    let message = newData(50 * 1024)
    let serverDone = newFuture[void]()
    let clientDone = newFuture[void]()
    var clientDoneCount: int
    var serverDoneCount: int
    const count = 2

    proc accept() {.async.} =
      while true:
        let connection =
          try:
            await listener.accept()
          except CatchableError:
            return
        let stream = await connection.incomingStream()
        let receivedData = await readStreamTillEOF(stream)
        checkEqual(message, receivedData)

        await stream.close()
        await connection.waitClosed()

        serverDoneCount.inc
        if serverDoneCount == count:
          serverDone.complete()

    proc runClient() {.async.} =
      let client = makeClient()
      let connection = await client.dial(address)

      let stream = await connection.openStream()
      await stream.write(message)
      await stream.close()
      await connection.close()

      clientDoneCount.inc
      if clientDoneCount == count:
        clientDone.complete()

    for i in 0 ..< count:
      asyncSpawn runClient()

    asyncSpawn accept()
    waitFor allSucceeded(serverDone, clientDone)
    await listener.stop()
    listener.destroy()
