import ngtcp2
import ./certificateverifier

type InsecureCertificateVerifier* = ref object of CertificateVerifier

proc init*(
    t: typedesc[InsecureCertificateVerifier]
): InsecureCertificateVerifier {.gcsafe.} =
  return InsecureCertificateVerifier()

method verify*(
    self: InsecureCertificateVerifier,
    serverName: string,
    derCertificates: seq[seq[byte]],
): bool =
  return true
