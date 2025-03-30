import ngtcp2
import results
import sequtils
import ./certificateverifier
import ../pointers
import ../../../../helpers/openarray
import ../../../../errors

type
  extVerifyCertificateT = object of ptls_verify_certificate_t
    certificateVerifier*: Opt[CertificateVerifier]
    certificates*: seq[seq[byte]]

  ExtendedCertificateVerifier* = object
    verifier: ptr extVerifyCertificateT

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
  let certVerifier = cast[ptr extVerifyCertificateT](self)

  var derCertificates = newSeq[seq[byte]](num_certs)
  for i in 0 ..< int(num_certs):
    let cert = certs + i
    derCertificates[i] = toSeq(toOpenArray(cert.base, cert.len))

  certVerifier.certificates = derCertificates

  if certVerifier.certificateVerifier.isSome:
    let v = certVerifier.certificateVerifier.get()
    return v.verify($server_name, derCertificates)

  return 0

proc init*(
    t: typedesc[ExtendedCertificateVerifier], verifier: Opt[CertificateVerifier]
): ExtendedCertificateVerifier {.gcsafe.} =
  var response = ExtendedCertificateVerifier()
  response.verifier = create(extVerifyCertificateT)
  var algos = cast[ptr UncheckedArray[uint16]](alloc(uint16.sizeof * 3))
  algos[0] = PTLS_SIGNATURE_ECDSA_SECP256R1_SHA256
  algos[1] = PTLS_SIGNATURE_ED25519
  algos[2] = high(uint16)
  response.verifier.cb = validateCertificate
  response.verifier.algos = cast[ptr uint16](algos)
  response.verifier.certificateVerifier = verifier
  return response

proc destroy*(t: var ExtendedCertificateVerifier) {.gcsafe.} =
  if t.verifier.isNil:
    return

  let algosPtr = cast[pointer](t.verifier.algos)
  dealloc(algosPtr)
  dealloc(t.verifier)

  t.verifier = nil

proc getPtlsVerifyCertificateT*(
    t: ExtendedCertificateVerifier
): ptr ptls_verify_certificate_t =
  return t.verifier

proc certificates*(self: ExtendedCertificateVerifier): seq[seq[byte]] {.raises: [].} =
  self.verifier.certificates
