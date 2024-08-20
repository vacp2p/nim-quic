from pkg/ngtcp2 import NGTCP2_PROTO_VER_V2

const DraftVersion29 = 0xFF00001D'u32
const CurrentQuicVersion* = cast[uint32](NGTCP2_PROTO_VER_V2)
