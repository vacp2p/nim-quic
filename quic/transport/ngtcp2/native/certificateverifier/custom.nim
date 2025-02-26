import ngtcp2
import sequtils
import ./certificateverifier
import ../pointers
import ../../../../helpers/openarray

type
  certificateVerifierCB* =
    proc(derCertificates: seq[seq[byte]]): bool {.gcsafe, noSideEffect.}

  customPTLSVerifyCertificateT = object of ptls_verify_certificate_t
    customCertVerifier: certificateVerifierCB

  CustomCertificateVerifier* = ref object of CertificateVerifier
    verifier: ptr customPTLSVerifyCertificateT

proc validateCertificate(
    self: ptr ptls_verify_certificate_t,
    tls: ptr ptls_t,
    server_name: cstring,
    verify_sign: proc(
      verify_ctx: pointer, algo: uint16, data: ptls_iovec_t, sign: ptls_iovec_t
    ): cint {.cdecl.},
    verify_data: ptr pointer,
    certs: ptr ptls_iovec_t,
    num_certs: csize_t,
): cint {.cdecl.} =
  let certVerifier = cast[ptr customPTLSVerifyCertificateT](self)
  if certVerifier.customCertVerifier.isNil:
    doAssert false, "custom cert verifier was not setup"

  var derCertificates = newSeq[seq[byte]](num_certs)
  for i in 0 ..< int(num_certs):
    let cert = certs + i
    derCertificates[i] = toSeq(toOpenArray(cert.base, cert.len))

  if certVerifier.customCertVerifier(derCertificates):
    return 0
  else:
    return PTLS_ALERT_BAD_CERTIFICATE

proc init*(
    t: typedesc[CustomCertificateVerifier], certVerifierCB: certificateVerifierCB
): CustomCertificateVerifier {.gcsafe.} =
  let response = CustomCertificateVerifier()
  response.verifier = create(customPTLSVerifyCertificateT)
  var algos = cast[ptr UncheckedArray[uint16]](alloc(uint16.sizeof * 5))
  algos[0] = PTLS_SIGNATURE_RSA_PSS_RSAE_SHA256
  algos[1] = PTLS_SIGNATURE_ECDSA_SECP256R1_SHA256
  algos[2] = PTLS_SIGNATURE_RSA_PKCS1_SHA256
  algos[3] = PTLS_SIGNATURE_RSA_PKCS1_SHA1
  algos[4] = high(uint16)
  response.verifier.cb = validateCertificate
  response.verifier.algos = cast[ptr uint16](algos)
  response.verifier.customCertVerifier = certVerifierCB
  return response

method destroy*(t: CustomCertificateVerifier) {.gcsafe.} =
  if t.verifier.isNil:
    return

  let algosPtr = cast[pointer](t.verifier.algos)
  dealloc(algosPtr)
  dealloc(t.verifier)
  t.verifier = nil

method getPtlsVerifyCertificateT*(
    t: CustomCertificateVerifier
): ptr ptls_verify_certificate_t =
  return t.verifier
