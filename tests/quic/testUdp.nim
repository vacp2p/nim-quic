import std/unittest
import std/sequtils
import chronos
import quic
import ../helpers/asynctest
import ../helpers/addresses

suite "udp":

  asynctest "writes packets to datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    await client.write()
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asynctest "reads packets from datagram":
    let client = newClientConnection(zeroAddress, zeroAddress)
    await client.write()
    let datagram = await client.outgoing.get()
    let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
    server.read(datagram)

  test "raises error when reading datagram fails":
    let datagram = repeat(0'u8, 4096)
    let server = newServerConnection(zeroAddress, zeroAddress, datagram)

    expect IOError:
      server.read(datagram)

  test "raises error when reading empty datagram":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      client.read(@[])
