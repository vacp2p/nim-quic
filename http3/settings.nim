import tables

type HTTP3Settings* = object
  enableDatagrams*: bool
  enableExtendedConnect*: bool
  other: Table[uint64, uint64]
