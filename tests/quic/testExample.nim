import std/unittest
import ../helpers/asynctest
import pkg/quic
import pkg/chronos

suite "examples from Readme":

  test "outgoing and incoming connections":

    proc outgoing {.async.} =
      let connection = await dial(initTAddress("127.0.0.1:12345"))
      let stream = await connection.openStream()
      let message = cast[seq[byte]]("some message")
      await stream.write(message)
      await stream.close()
      await connection.waitClosed()

    proc incoming {.async.} =
      let listener = listen(initTAddress("127.0.0.1:12345"))
      let connection = await listener.accept()
      let stream = await connection.incomingStream()
      let message = await stream.read()
      await stream.close()
      await connection.close()
      await listener.stop()

      check message == cast[seq[byte]]("some message")

    waitFor allSucceeded(incoming(), outgoing())
