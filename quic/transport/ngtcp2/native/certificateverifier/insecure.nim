import ngtcp2
import ./certificateverifier

type InsecureCertificateVerifier* = ref object of CertificateVerifier

proc init*(t: typedesc[InsecureCertificateVerifier]): InsecureCertificateVerifier {.gcsafe.} =
  return InsecureCertificateVerifier()

method destroy*(t: InsecureCertificateVerifier) {.gcsafe.} =
  discard

method getPtlsVerifyCertificateT*(
    t: InsecureCertificateVerifier
): ptr ptls_verify_certificate_t =
  # picotls will check against null to determine whether a certificate verifier
  # was setup or not
  return nil 
