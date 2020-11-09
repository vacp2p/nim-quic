import std/unittest
import std/sequtils
import chronos
import quic
import ../helpers/asynctest
import ../helpers/addresses

suite "udp":

  asynctest "sends outgoing datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    client.send()
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asynctest "processes received datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    client.send()
    let datagram = await client.outgoing.get()
    let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
    server.receive(datagram)

  test "raises error when receiving bad datagram":
    let datagram = repeat(0'u8, 4096)
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.receive(datagram)

  test "raises error when receiving empty datagram":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      client.receive(@[])
