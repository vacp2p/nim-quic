import ngtcp2

type CertificateVerifier* = ref object of RootObj

method destroy*(t: CertificateVerifier) {.base, gcsafe.} =
  doAssert false, "override this method"

method verify*(
    self: CertificateVerifier, serverName: string, derCertificates: seq[seq[byte]]
): cint {.base.} =
  doAssert false, "override this method"
