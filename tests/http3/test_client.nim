import pkg/unittest2
import stew/byteutils
import random
import results
import ../helpers/async
import pkg/chronos
import ../../http3/client
import ../../quic/api
import ../helpers/certificate

suite "HTTP3":
  test "Client":
    let tlsConfig = TLSConfig.init(testCertificate(), testPrivateKey(), @["h3"])
    let address = initTAddress("127.0.0.1:4434")
    var message = newSeq[byte](50 * 1024) # 50kib
    for i in 0 ..< message.len:
      message[i] = rand(0'u8 .. 255'u8)

    proc outgoing() {.async.} =
      defer:
        echo "client finished"

      let qClient = QuicClient.init(tlsConfig)
      let qConn =
        try:
          await qClient.dial(address)
        except CatchableError as e:
          raiseAssert "dial failed with error: " & $e.msg

      # initialize and setup http3 conn using quic conn
      let http3Client = HTTP3Client.init(qConn)
      defer:
        http3Client.destroy()

      # receive settings
      let settings = await http3Client.settings().wait(4.seconds)
      check settings.enableDatagrams

      #  open stream
      let s = await http3Client.openRequestStream()

      # send http request header
      # ... method connect, etc

      # receive response 
      # ... validate status code

    proc incoming() {.async.} =
      return # local test with echo server

      # let server = QuicServer.init(tlsConfig)
      # let listener = server.listen(address)

      # let connection = await listener.accept()
      # check connection.certificates().len == 1
      # let stream = await connection.incomingStream()

      # var read: seq[byte] = @[]
      # while read.len < message.len:
      #   let readMessage = await stream.read()
      #   read = read & readMessage

      # check read.toHex() == message.toHex()

      # # todo write message back to client

      # await stream.close()
      # await connection.waitClosed()
      # await listener.stop()
      # listener.destroy()

    waitFor allSucceeded(incoming(), outgoing())
