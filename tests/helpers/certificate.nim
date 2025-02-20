import sequtils
import os

const certificateStr =
  staticRead(parentDir(currentSourcePath()) / "testCertificate.pem")
const privateKeyStr = staticRead(parentDir(currentSourcePath()) / "testPrivateKey.pem")

proc strToSeq(val: string): seq[byte] =
  toSeq(val.toOpenArrayByte(0, val.high))

proc testCertificate*(): seq[byte] =
  strToSeq(certificateStr)

proc testPrivateKey*(): seq[byte] =
  strToSeq(privateKeyStr)
