proc `+`*[T](p: ptr T, a: int): ptr T =
  cast[ptr T](cast[ByteAddress](p) + ByteAddress(a))
