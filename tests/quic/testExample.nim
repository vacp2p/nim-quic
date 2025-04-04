import results
import pkg/unittest2
import ../helpers/async
import pkg/quic
import pkg/chronos
import ../helpers/certificate

suite "examples from Readme":
  test "outgoing and incoming connections":
    let message = cast[seq[byte]]("some message")
    let alpn = @["test"]
    proc outgoing() {.async.} =
      let cb = proc(serverName: string, derCertificates: seq[seq[byte]]): bool {.gcsafe.} =
        # TODO: implement custom certificate validation
        return derCertificates.len > 0

      let customCertVerif: CertificateVerifier = CustomCertificateVerifier.init(cb)
      let tlsConfig =
        TLSConfig.init(testCertificate(), testPrivateKey(), alpn, certificateVerifier = Opt.some(customCertVerif))
      let client = QuicClient.init(tlsConfig)
      let connection = await client.dial(initTAddress("127.0.0.1:12345"))
      
      check connection.certificates().len == 1

      let stream = await connection.openStream()
      await stream.write(message)
      await stream.close()
      await connection.close()

    proc incoming() {.async.} =
      let cb = proc(serverName: string, derCertificates: seq[seq[byte]]): bool {.gcsafe.} =
        return derCertificates.len > 0
      let customCertVerif: CertificateVerifier = CustomCertificateVerifier.init(cb)
      let tlsConfig = TLSConfig.init(testCertificate(), testPrivateKey(), alpn,  Opt.some(customCertVerif))
      let server = QuicServer.init(tlsConfig)
      let listener = server.listen(initTAddress("127.0.0.1:12345"))

      let connection = await listener.accept()
      check connection.certificates().len == 1
      let stream = await connection.incomingStream()
      let readMessage = await stream.read()
      await stream.close()
      await connection.waitClosed()
      await listener.stop()
      listener.destroy()
      check readMessage == message

    waitFor allSucceeded(incoming(), outgoing())
