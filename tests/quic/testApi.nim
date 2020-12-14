import std/unittest
import pkg/chronos
import pkg/quic
import ../helpers/asynctest

suite "api":

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

    await outgoing.drop()
    await incoming.drop()

  asynctest "opens and drops streams":
    let listener = listen(address)
    defer: await listener.stop()

    let dialing = dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    let stream1 = await outgoing.openStream()
    let stream2 = await incoming.openStream()

    await stream1.close()
    await stream2.close()

    await outgoing.drop()
    await incoming.drop()

  asynctest "accepts multiple incoming connections":
    let listener = listen(address)
    defer: await listener.stop()

    let accepting1 = listener.accept()
    let outgoing1 = await dial(address)
    let incoming1 = await accepting1

    let accepting2 = listener.accept()
    let outgoing2 = await dial(address)
    let incoming2 = await accepting2

    check incoming1 != incoming2

    await outgoing1.drop()
    await outgoing2.drop()
    await incoming1.drop()
    await incoming2.drop()

  asynctest "writes to and reads from streams":
    let message = @[1'u8, 2'u8, 3'u8]

    let listener = listen(address)
    defer: await listener.stop()

    let outgoing = await dial(address)
    defer: await outgoing.drop()

    let incoming = await listener.accept()
    defer: await incoming.drop()

    let outgoingStream = await outgoing.openStream()
    defer: await outgoingStream.close()

    await outgoingStream.write(message)

    let incomingStream = await incoming.incomingStream()
    defer: await incomingStream.close()

    check (await incomingStream.read()) == message
