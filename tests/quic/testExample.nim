import results
import pkg/unittest2
import ../helpers/async
import pkg/quic
import pkg/chronos
import ../helpers/certificate

suite "examples from Readme":
  test "outgoing and incoming connections":
    let message = cast[seq[byte]]("some message") 
    proc outgoing() {.async.} =
      let cb = proc(derCertificates: seq[seq[byte]]): bool {.gcsafe.} =
        # TODO: implement custom certificate validation
        return derCertificates.len > 0

      let customCertVerif: CertificateVerifier = CustomCertificateVerifier.init(cb)
      let tlsConfig = TLSConfig.init(certificateVerifier = Opt.some(customCertVerif))
      let client = QuicClient.init(tlsConfig)
      let connection = await client.dial(initTAddress("127.0.0.1:12345"))
      let stream = await connection.openStream()
      await stream.write(message)
      await stream.close()
      await connection.close()

    proc incoming() {.async.} =
      let tlsConfig = TLSConfig.init(testCertificate(), testPrivateKey())
      let server = QuicServer.init(tlsConfig)
      let listener = server.listen(initTAddress("127.0.0.1:12345"))

      let connection = await listener.accept()
      let stream = await connection.incomingStream()
      let readMessage = await stream.read()
      await stream.close()
      await connection.waitClosed()
      await listener.stop()
      listener.destroy()
      check readMessage == message

    waitFor allSucceeded(incoming(), outgoing())
