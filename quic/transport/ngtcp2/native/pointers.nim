proc `+`*[T](p: ptr T, a: int): ptr T =
  cast[ptr T](cast[uint](p) + uint(a))
