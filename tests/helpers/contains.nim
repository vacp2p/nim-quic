proc contains*(a: seq[byte], sub: seq[byte]): bool =
  for i in 0 ..< a.len - sub.len:
    if a[i ..< i + sub.len] == sub:
      return true
