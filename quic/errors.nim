type
  QuicConfigError* = object of CatchableError
  QuicError* = object of IOError
  ClosedStreamError* = object of QuicError
