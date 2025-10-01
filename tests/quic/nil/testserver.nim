import pkg/quic
import pkg/chronos
import ../../helpers/[stream, clientserver]

proc run() {.async.} =
  let address = initTAddress("127.0.0.1:12345")
  let server = makeServer()
  let listener = server.listen(address)
  let message = newData(150 * 1024)

  proc handleConn(connection: Connection) {.async.} =
    echo "conn accepted"
    try:
      let stream = await connection.incomingStream()
      let receivedData = await readStreamTillEOF(stream)
      await stream.write(receivedData)
      await stream.close()
      echo "completed"
    except CatchableError as e:
      echo "failed: " & $e.msg
    finally:
      await connection.close()

  proc accept() {.async.} =
    while true:
      let connection =
        try:
          await listener.accept()
        except CatchableError as e:
          echo "accept error: " & e.msg
          return

      asyncSpawn handleConn(connection)

  asyncSpawn accept()
  await newFuture[void]() 


waitFor(run())