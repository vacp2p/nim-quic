import results
import pkg/unittest2
import ../helpers/async
import pkg/quic
import pkg/chronos
import ../helpers/certificate

suite "examples from Readme":
  test "outgoing and incoming connections":
    proc outgoing() {.async.} =
      let connection = await dial(initTAddress("127.0.0.1:12345"))
      echo "OPENING STREAM"
      let stream = await connection.openStream()
      let message = cast[seq[byte]]("some message")
      echo "WRITING TO STREAM"
      await stream.write(message)
      await sleepAsync(10.seconds)
      let x = await stream.read()
      echo "CLOSING"
      await stream.close()
      await connection.close()
      echo "DONE OUTGOING"

 
    proc incoming() {.async.} =
      let listener =
        listen(initTAddress("127.0.0.1:12345"), TLSConfig.init(testCertificate(), testPrivateKey()))

      echo "INCOMING: ======== ACCEPTING ===== "
      let connection = await listener.accept()
      echo "INCOMING: === INCOMING STREAM ====== "
      let stream = await connection.incomingStream()
      echo "INCOMING: WAITING FOR READ"
      let message = await stream.read()
      echo ">>>>>>>>>>>>>>>> INCOMING: READ!"
      await stream.write(cast[seq[byte]]("Message 2!!!"))
      echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>WROTE!"
      await stream.close()
      await connection.waitClosed()
      echo "INCOMING: CLOSED"
      await listener.stop()
      echo "INCOMING: DONE INCOMING"
      listener.destroy()
      check message == cast[seq[byte]]("some message")

    waitFor allSucceeded(incoming(), outgoing())
