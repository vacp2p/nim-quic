import results
import ngtcp2
import std/sets
import bearssl/rand
import ./ngtcp2/native
import ../errors

export CertificateVerifier
export certificateVerifierCB
export CustomCertificateVerifier
export InsecureCertificateVerifier
export init
export destroy

type TLSBackend* = ref object
  ctx*: TLSContext

proc newServerTLSBackend*(
    certificate: seq[byte],
    key: seq[byte],
    alpn: HashSet[string] = initHashSet[string](),
    certificateVerifier: Opt[CertificateVerifier],
): TLSBackend {.raises: [QuicError].} =
  let tlsCtx = TLSContext.init(
    certificate, key, alpn, certificateVerifier, certificateVerifier.isSome, true
  ).valueOr:
    raise newException(QuicError, "could not configure server context: " & error)
  return TLSBackend(ctx: tlsCtx)

proc newClientTLSBackend*(
    certificate: seq[byte],
    key: seq[byte],
    alpn: HashSet[string] = initHashSet[string](),
    certificateVerifier: Opt[CertificateVerifier],
): TLSBackend {.raises: [QuicError].} =
  let tlsCtx = TLSContext.init(
    certificate, key, alpn, certificateVerifier, false, false
  ).valueOr:
    raise newException(QuicError, "could not configure client context: " & error)
  return TLSBackend(ctx: tlsCtx)

proc destroy*(self: TLSBackend) =
  if self.ctx.isNil:
    return

  self.ctx.destroy()
  self.ctx = nil
