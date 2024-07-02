import chronicles

import ./basics
import ./transport/connectionid
import ./transport/stream
import ./transport/quicconnection
import ./transport/quicclientserver
import ./helpers/asyncloop

export Stream, close, read, write

logScope:
  topics = "quic connection"

type
  Connection* = ref object of RootObj
    udp: DatagramTransport
    remote: TransportAddress
    quic: QuicConnection
    loop: Future[void]
    onClose: Opt[proc() {.gcsafe, upraises: [].}]
    closed: AsyncEvent
  IncomingConnection = ref object of Connection
  OutgoingConnection = ref object of Connection

proc ids*(connection: Connection): seq[ConnectionId] =
  connection.quic.ids

proc `onNewId=`*(connection: Connection, callback: IdCallback) =
  connection.quic.onNewId = callback

proc `onRemoveId=`*(connection: Connection, callback: IdCallback) =
  connection.quic.onRemoveId = callback

proc `onClose=`*(connection: Connection, callback: proc() {.gcsafe, upraises: [].}) =
  connection.onClose = Opt.some(callback)

proc drop*(connection: Connection) {.async.} =
  trace "Dropping connection"
  await connection.quic.drop()
  trace "Dropped connection"

proc close*(connection: Connection) {.async.} =
  await connection.quic.close()

proc waitClosed*(connection: Connection) {.async.} =
  await connection.closed.wait()

proc startSending(connection: Connection, remote: TransportAddress) =
  debug "Starting sending loop"
  proc send {.async.} =
    try:
      trace "Getting datagram"
      let datagram = await connection.quic.outgoing.get()
      trace "Sending datagraom", remote
      await connection.udp.sendTo(remote, datagram.data)
      trace "Sent datagraom"
    except TransportError as e:
      debug "Failed to send datagram", errorMsg = e.msg
      trace "Failing connection loop future with error"
      connection.loop.fail(e) # This might need to be revisited, see https://github.com/status-im/nim-quic/pull/41 for more details
      await connection.drop()
  connection.loop = asyncLoop(send)

proc stopSending(connection: Connection) {.async.} =
  debug "Stopping sending loop"
  await connection.loop.cancelAndWait()
  debug "Stopped sending loop"

method closeUdp(connection: Connection) {.async, base, upraises: [].} =
  discard

method closeUdp(connection: OutgoingConnection) {.async.} =
  await connection.udp.closeWait()

proc disconnect(connection: Connection) {.async.} =
  trace "Disconnecting connection"
  trace "Stop sending in the connection"
  await connection.stopSending()
  trace "Stopped sending in the connection"
  trace "Closing udp"
  await connection.closeUdp()
  trace "Closed udp"
  if connection.onClose.isSome():
    trace "Calling onClose"
    (connection.onClose.unsafeGet())()
    trace "Called onClose"
  trace "Firing closed event"
  connection.closed.fire()
  trace "Fired closed event"

proc newIncomingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let datagram = Datagram(data: udp.getMessage())
  let quic = newQuicServerConnection(udp.localAddress, remote, datagram)
  let closed = newAsyncEvent()
  let connection = IncomingConnection(udp: udp, quic: quic, closed: closed)
  proc onDisconnect {.async.} =
    trace "Calling onDisconnect for newIncomingConnection"
    await connection.disconnect()
    trace "Called onDisconnect for newIncomingConnection"
  connection.remote = remote
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)
  connection

proc newOutgoingConnection*(udp: DatagramTransport,
                           remote: TransportAddress): Connection =
  let quic = newQuicClientConnection(udp.localAddress, remote)
  let closed = newAsyncEvent()
  let connection = OutgoingConnection(udp: udp, quic: quic, closed: closed)
  proc onDisconnect {.async.} =
    trace "Calling onDisconnect for newOutgoingConnection"
    await connection.disconnect()
    trace "Called onDisconnect for newOutgoingConnection"
  connection.remote = remote
  quic.disconnect = Opt.some(onDisconnect)
  connection.startSending(remote)
  connection

proc startHandshake*(connection: Connection) =
  connection.quic.send()

proc receive*(connection: Connection, datagram: Datagram) =
  connection.quic.receive(datagram)

proc remoteAddress*(connection: Connection): TransportAddress {.
    raises: [Defect, TransportOsError].} =
  connection.remote

proc localAddress*(connection: Connection): TransportAddress {.
    raises: [Defect, TransportOsError].} =
  connection.udp.localAddress()

proc openStream*(connection: Connection,
                 unidirectional = false): Future[Stream] {.async.} =
  await connection.quic.handshake.wait()
  result = await connection.quic.openStream(unidirectional = unidirectional)

proc incomingStream*(connection: Connection): Future[Stream] {.async.} =
  result = await connection.quic.incomingStream()
