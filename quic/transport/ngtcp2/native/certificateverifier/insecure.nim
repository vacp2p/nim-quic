import ngtcp2
import ./certificateverifier

type InsecureCertificateVerifier* = ref object of CertificateVerifier

proc init*(
    t: typedesc[InsecureCertificateVerifier]
): InsecureCertificateVerifier {.gcsafe.} =
  return InsecureCertificateVerifier()

method destroy*(t: InsecureCertificateVerifier) {.gcsafe.} =
  discard

method verify*(
    self: InsecureCertificateVerifier,
    serverName: string,
    derCertificates: seq[seq[byte]],
): cint =
  return 0
