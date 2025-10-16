import ngtcp2
import results
import ../../../helpers/sequninit

proc x509toDERBytes*(cert: ptr X509): Opt[seq[byte]] =
  let derBuf: ptr uint8 = nil
  let derLen = i2d_X509(cert, addr derBuf)
  if derLen != 0:
    let outp = newSeqUninit[byte](derLen)
    copyMem(addr outp[0], derBuf, derLen)
    return Opt.some(outp)
  return Opt.none(seq[byte])

proc getFullCertChain*(ssl: ptr SSL): seq[seq[byte]] =
  var output: seq[seq[byte]] = @[]
  let chain = SSL_get_peer_full_cert_chain(ssl)
  if not chain.isNil:
    let x509num = OPENSSL_sk_num(cast[ptr OPENSSL_STACK](chain))
    for i in 0 ..< x509num:
      let chainC = OPENSSL_sk_value(cast[ptr OPENSSL_STACK](chain), csize_t(i))
      let certBytes = x509toDERBytes(cast[ptr X509](chainC))
      if certBytes.isSome:
        output.add(certBytes.value())

  return output
