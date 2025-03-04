import pkg/unittest2
import std/sequtils
import pkg/quic/transport/packets
import pkg/quic/transport/packets/varints

suite "packet length":
  const destination = ConnectionId(@[3'u8, 4'u8, 5'u8])
  const source = ConnectionId(@[1'u8, 2'u8])
  const token = @[0xA'u8, 0xB'u8, 0xC'u8]

  test "knows the length of a version negotiation packet":
    var packet = versionNegotiationPacket()
    const versions = @[1'u32, 2'u32, 3'u32]
    packet.destination = destination
    packet.source = source
    packet.negotiation.supportedVersions = versions
    check packet.len == 7 + destination.len + source.len + 4 * versions.len

  test "knows the length of a retry packet":
    var packet = retryPacket()
    packet.destination = destination
    packet.source = source
    packet.retry.token = token
    packet.retry.integrity[0 .. 15] = repeat(0xA'u8, 16)
    check packet.len == 7 + destination.len + source.len + token.len + 16

  test "knows the length of a handshake packet":
    var packet = handshakePacket()
    packet.destination = destination
    packet.source = source
    packet.handshake.packetnumber = 0x00BBCCDD'u32.int64
    packet.handshake.payload = repeat(0xEE'u8, 1024)
    check packet.len ==
      7 + destination.len + source.len + 1024.toVarInt.len + # packet length
      3 + # packet number
      1024 # payload

  test "knows the length of a 0-RTT packet":
    var packet = zeroRttPacket()
    packet.destination = destination
    packet.source = source
    packet.rtt.packetnumber = 0x00BBCCDD'u32.int64
    packet.rtt.payload = repeat(0xEE'u8, 1024)
    check packet.len ==
      7 + destination.len + source.len + 1024.toVarInt.len + # packet length
      3 + # packet number
      1024 # payload

  test "knows the length of an initial packet":
    var packet = initialPacket()
    packet.destination = destination
    packet.source = source
    packet.initial.token = token
    packet.initial.packetnumber = 0x00BBCCDD'u32.int64
    packet.initial.payload = repeat(0xEE'u8, 1024)
    check packet.len ==
      7 + destination.len + source.len + token.len.toVarInt.len + token.len +
      1024.toVarInt.len + # packet length
      3 + # packet number
      1024 # payload

  test "knows the length of a short packet":
    var packet = shortPacket()
    packet.destination = destination
    packet.short.packetnumber = 0x00BBCCDD'u32.int64
    packet.short.payload = repeat(0xEE'u8, 1024)
    check packet.len ==
      1 + destination.len + 3 + # packet number
      1024 # payload
