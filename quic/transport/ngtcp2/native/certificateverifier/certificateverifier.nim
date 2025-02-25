import ngtcp2

type CertificateVerifier* = ref object of RootObj

method destroy*(t: CertificateVerifier) {.base, gcsafe.} =
  doAssert false, "override this method"

method getPtlsVerifyCertificateT*(
    t: CertificateVerifier
): ptr ptls_verify_certificate_t {.base, gcsafe.} =
  doAssert false, "override this method"
