import results
import pkg/unittest2
import pkg/quic
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import ../helpers/[stream, clientserver]

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
  asyncTest "client to server send and receive message":
    let message = newData(1024 * 1024)
    let address = initTAddress("127.0.0.1:12345")

    let
      client = makeClient()
      server = makeServer()
      listener = server.listen(address)
      dialing = client.dial(address)
      accepting = listener.accept()

    proc outgoing(connection: Connection) {.async.} =
      check connection.certificates().len == 1
      let stream = await connection.openStream()
      await stream.write(message)
      await stream.close()

    proc incoming(connection: Connection) {.async.} =
      check connection.certificates().len == 1

      let stream = await connection.incomingStream()
      let receivedData = await readStreamTillEOF(stream)
      checkEqual(message, receivedData)

      await stream.close()

    let clientConn = await dialing
    let serverConn = await accepting

    await allFutures(serverConn.incoming(), clientConn.outgoing())

    # closing connections after server and client finished work, because if we 
    # closed earlier data sent via connection may not be received by other end 
    # fully in time
   # echo "A"
   # await clientConn.close()
   # echo "B"
   # await serverConn.close()
   # echo "C"
   # await listener.stop()
    await allFutures(clientConn.close(), serverConn.close(), listener.stop())

