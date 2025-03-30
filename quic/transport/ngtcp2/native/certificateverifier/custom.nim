import ngtcp2
import ./certificateverifier

type
  certificateVerifierCB* =
    proc(serverName: string, derCertificates: seq[seq[byte]]): bool {.gcsafe.}

  CustomCertificateVerifier* = ref object of CertificateVerifier
    verifierCB: certificateVerifierCB

method verify*(
    self: CustomCertificateVerifier, serverName: string, derCertificates: seq[seq[byte]]
): cint =
  if self.verifierCB.isNil:
    doAssert false, "custom cert verifier was not setup"
  if self.verifierCB(serverName, derCertificates):
    return 0
  else:
    return PTLS_ALERT_BAD_CERTIFICATE

proc init*(
    t: typedesc[CustomCertificateVerifier], certVerifierCB: certificateVerifierCB
): CustomCertificateVerifier {.gcsafe.} =
  let response = CustomCertificateVerifier()
  response.verifierCB = certVerifierCB
  return response

method destroy*(t: CustomCertificateVerifier) {.gcsafe.} =
  discard
