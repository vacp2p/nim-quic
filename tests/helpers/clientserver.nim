import results
import pkg/quic
import ./certificate

proc certificateCb(
    serverName: string, derCertificates: seq[seq[byte]]
): bool {.gcsafe.} =
  return derCertificates.len > 0

proc makeClient*(): QuicClient =
  let customCertVerif: CertificateVerifier =
    CustomCertificateVerifier.init(certificateCb)
  let alpn = @["test"]
  let tlsConfig = TLSConfig.init(
    testCertificate(),
    testPrivateKey(),
    alpn,
    certificateVerifier = Opt.some(customCertVerif),
  )
  return QuicClient.init(tlsConfig)

proc makeServer*(): QuicServer =
  let customCertVerif: CertificateVerifier =
    CustomCertificateVerifier.init(certificateCb)
  let alpn = @["test"]
  let tlsConfig =
    TLSConfig.init(testCertificate(), testPrivateKey(), alpn, Opt.some(customCertVerif))
  return QuicServer.init(tlsConfig)
