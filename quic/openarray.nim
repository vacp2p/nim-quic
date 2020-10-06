proc `[]=`*[T,U,V](
  target: var openArray[T],
  slice: HSlice[U,V],
  replacement: openArray[T]
) =
  doAssert replacement.len == slice.len
  for i in 0..<replacement.len:
    target[slice.a + i] = replacement[i]

template toOpenArray*[T](a: ptr T, length: uint): openArray[T] =
  toOpenArray(cast[ptr UncheckedArray[T]](a), 0, length.int-1)
