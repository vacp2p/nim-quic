import std/unittest
import pkg/chronos
import pkg/quic
import ../helpers/asynctest

suite "connection":

  let address = initTAddress("127.0.0.1:48579")

  asynctest "listens on a local udp port for incoming quic connections":
    let listener = listen(address)
    await listener.stop()

  asynctest "opens and closes connections":
    let listener = listen(address)
    defer: await listener.stop()

    let dialing = dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    await outgoing.close()
    await incoming.close()

  asynctest "opens and closes streams":
    let listener = listen(address)
    defer: await listener.stop()

    let dialing = dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    let stream1 = await outgoing.openStream()
    let stream2 = await incoming.openStream()

    stream1.close()
    stream2.close()

    await outgoing.close()
    await incoming.close()
