import ../../../basics

const ZeroMoment = Moment.init(0, 1.nanoseconds)

proc now*(): uint64 =
  (Moment.now() - ZeroMoment).nanos.uint64
