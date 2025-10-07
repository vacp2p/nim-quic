import ngtcp2

type CertificateVerifier* = ref object of RootObj

method destroy*(t: CertificateVerifier) {.base, gcsafe.} =
  raiseAssert "override method: destroy"

method verify*(
    self: CertificateVerifier, serverName: string, derCertificates: seq[seq[byte]]
): cint {.base.} =
  raiseAssert "override method: verify"
