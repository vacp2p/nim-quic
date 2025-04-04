type
  ExplicitCongestionNotification* {.size: 1.} = enum
    ecnNonCapable = 0b00
    ecnCapable1 = 0b01
    ecnCapable0 = 0b10
    ecnCongestion = 0b11

  ECN* = ExplicitCongestionNotification
