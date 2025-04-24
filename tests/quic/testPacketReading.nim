import std/sequtils
import pkg/unittest2
import pkg/quic/transport/packets
import pkg/quic/helpers/bits

suite "packet reading":
  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "reads long/short form":
    datagram.write(shortPacket())
    check readPacket(datagram).form == formShort
    datagram.write(initialPacket())
    check readPacket(datagram).form == formLong

  test "checks fixed bit":
    datagram.write(shortPacket())
    datagram[0].bits[1] = 0
    expect CatchableError:
      discard readPacket(datagram)

  test "reads packet type":
    datagram.write(initialPacket())
    check readPacket(datagram).kind == packetInitial
    datagram.write(zeroRttPacket())
    check readPacket(datagram).kind == packet0RTT
    datagram.write(handshakePacket())
    check readPacket(datagram).kind == packetHandshake
    datagram.write(retryPacket())
    check readPacket(datagram).kind == packetRetry

  test "reads version negotiation packet":
    let length = datagram.write(versionNegotiationPacket())
    check readPacket(datagram[0 ..< length]).kind == packetVersionNegotiation

  test "reads version":
    const version = 0xAABBCCDD'u32
    datagram.write(initialPacket(version = version))
    check readPacket(datagram).initial.version == version

  test "reads source connection id":
    const source = ConnectionId(@[1'u8, 2'u8, 3'u8])
    var packet = initialPacket()
    packet.source = source
    datagram.write(packet)
    check readPacket(datagram).source == source

  test "reads destination connection id":
    const destination = ConnectionId(@[4'u8, 5'u8, 6'u8])
    var packet = initialPacket()
    packet.destination = destination
    datagram.write(packet)
    check readPacket(datagram).destination == destination

  test "reads supported versions in version negotiation packet":
    const versions = @[0xAABBCCDD'u32, 0x11223344'u32]
    let length = datagram.write(versionNegotiationPacket(versions = versions))
    let packet = readPacket(datagram[0 ..< length])
    check packet.negotiation.supportedVersions == versions

  test "reads token from retry packet":
    const token = @[1'u8, 2'u8, 3'u8]
    var packet = retryPacket()
    packet.retry.token = token
    let length = datagram.write(packet)
    check readPacket(datagram[0 ..< length]).retry.token == token

  test "reads integrity tag from retry packet":
    const integrity = repeat(0xA'u8, 16)
    var packet = retryPacket()
    packet.retry.integrity[0 ..< 16] = integrity
    let length = datagram.write(packet)
    check readPacket(datagram[0 ..< length]).retry.integrity == integrity

  test "reads packet number from handshake packet":
    const packetnumber = 0xABCD
    var packet = handshakePacket()
    packet.handshake.packetnumber = packetnumber
    datagram.write(packet)
    check readPacket(datagram).handshake.packetnumber == packetnumber

  test "reads payload from handshake packet":
    const payload = repeat(0xAB'u8, 1024)
    var packet = handshakePacket()
    packet.handshake.payload = payload
    datagram.write(packet)
    check readPacket(datagram).handshake.payload == payload

  test "reads packet number from 0-RTT packet":
    const packetnumber = 0xABCD
    var packet = zeroRttPacket()
    packet.rtt.packetnumber = packetnumber
    datagram.write(packet)
    check readPacket(datagram).rtt.packetnumber == packetnumber

  test "reads payload from 0-RTT packet":
    const payload = repeat(0xAB'u8, 1024)
    var packet = zeroRttPacket()
    packet.rtt.payload = payload
    datagram.write(packet)
    check readPacket(datagram).rtt.payload == payload

  test "reads token from initial packet":
    const token = repeat(0xAA'u8, 1024)
    var packet = initialPacket()
    packet.initial.token = token
    datagram.write(packet)
    check readPacket(datagram).initial.token == token

  test "reads packet number from initial packet":
    const packetnumber = 0xABCD
    var packet = initialPacket()
    packet.initial.packetnumber = packetnumber
    datagram.write(packet)
    check readPacket(datagram).initial.packetnumber == packetnumber

  test "reads payload from initial packet":
    const payload = repeat(0xAB'u8, 1024)
    var packet = initialPacket()
    packet.initial.payload = payload
    datagram.write(packet)
    check readPacket(datagram).initial.payload == payload

  test "reads spin bit from short packet":
    var packet = shortPacket()
    packet.short.spinBit = false
    datagram.write(packet)
    check readPacket(datagram).short.spinBit == false
    packet.short.spinBit = true
    datagram.write(packet)
    check readPacket(datagram).short.spinBit == true

  test "reads key phase from short packet":
    var packet = shortPacket()
    packet.short.keyPhase = false
    datagram.write(packet)
    check readPacket(datagram).short.keyPhase == false
    packet.short.keyPhase = true
    datagram.write(packet)
    check readPacket(datagram).short.keyPhase == true

  test "reads destination id from short packet":
    const destination = ConnectionId(repeat(0xAB'u8, 16))
    var packet = shortPacket()
    packet.destination = destination
    datagram.write(packet)
    check readPacket(datagram).destination == destination

  test "reads packet number from short packet":
    const packetnumber = 0xABCD
    var packet = shortPacket()
    packet.short.packetnumber = packetnumber
    packet.destination = ConnectionId(repeat(0'u8, DefaultConnectionIdLength))
    datagram.write(packet)
    check readPacket(datagram).short.packetnumber == packetnumber

  test "reads payload from short packet":
    const payload = repeat(0xAB'u8, 1024)
    var packet = shortPacket()
    packet.short.payload = payload
    packet.destination = ConnectionId(repeat(0'u8, DefaultConnectionIdLength))
    let length = datagram.write(packet)
    check readPacket(datagram[0 ..< length]).short.payload == payload
