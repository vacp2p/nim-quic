var FinSent*: bool = false
var FinReceived*: bool = false
var Flags*: uint32 = 0

proc ResetFin*() =
  FinSent = false
  FinReceived = false
  Flags = 0

proc PrintFin*() =
  echo "Sent: " & $FinSent
  echo "Received: " & $FinReceived
  echo "Flags: " & $Flags
