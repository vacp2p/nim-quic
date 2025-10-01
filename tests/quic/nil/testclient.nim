import pkg/quic
import pkg/chronos
import ../../helpers/[async, stream, clientserver]

proc run() {.async.} =
  let address = initTAddress("127.0.0.1:12345")
  let message = newData(150 * 1024)
  
  const count = 10
  let clientDone = newWaitGroup(count)

  proc runClient() {.async.} =
    try:
      let client = makeClient()
      let connection = await client.dial(address)

      let stream = await connection.openStream()
      await stream.write(message)
      await stream.closeWrite()
      let receivedData = await readStreamTillEOF(stream)
      echo "received data: " & $(receivedData == message)
      await stream.close()
      await connection.close()
    except CatchableError as e:
      echo "client failed: " & e.msg
    finally:
      clientDone.done()

  for i in 0 ..< count:
    asyncSpawn runClient()
  waitFor clientDone.wait()


waitFor(run())