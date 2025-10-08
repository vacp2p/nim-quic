import ngtcp2
import ./certificateverifier

type
  certificateVerifierCB* =
    proc(serverName: string, derCertificates: seq[seq[byte]]): bool {.gcsafe.}

  CustomCertificateVerifier* = ref object of CertificateVerifier
    verifierCB: certificateVerifierCB

method verify*(
    self: CustomCertificateVerifier, serverName: string, derCertificates: seq[seq[byte]]
): bool =
  if self.verifierCB.isNil:
    raiseAssert "custom cert verifier was not setup"
  return self.verifierCB(serverName, derCertificates)

proc init*(
    t: typedesc[CustomCertificateVerifier], certVerifierCB: certificateVerifierCB
): CustomCertificateVerifier {.gcsafe.} =
  let response = CustomCertificateVerifier()
  response.verifierCB = certVerifierCB
  return response
