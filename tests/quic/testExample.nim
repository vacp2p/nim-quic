import results
import pkg/unittest2
import ../helpers/async
import pkg/quic
import pkg/chronos
import ../helpers/certificate
import stew/byteutils
import random

suite "examples from Readme":
  test "outgoing and incoming connections":
    var message = newSeq[byte](50 * 1024) # 50kib
    for i in 0..<message.len:
      message[i] = rand(0'u8..255'u8)

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

      var read: seq[byte] = @[]
      while read.len < message.len:
        let readMessage = await stream.read()
        read = read & readMessage

      await stream.close()
      await connection.waitClosed()
      await listener.stop()
      listener.destroy()
      check read.toHex() == message.toHex()

    waitFor allSucceeded(incoming(), outgoing())
