import ngtcp2

type CertificateVerifier* = ref object of RootObj

method verify*(
    self: CertificateVerifier, serverName: string, derCertificates: seq[seq[byte]]
): bool {.base.} =
  raiseAssert "override method: verify"
