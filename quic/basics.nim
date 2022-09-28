import pkg/chronos
import pkg/upraises
import std/options
import ./udp/datagram
import ./errors

export chronos
export options
export datagram
export errors
export upraises

template getOr*[T](o: Option[T], otherwise: untyped): T =
  if o.isSome():
    o.unsafeGet()
  else:
    otherwise
