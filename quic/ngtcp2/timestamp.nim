import std/monotimes

proc now*: uint64 =
  getMonoTime().ticks.uint64
