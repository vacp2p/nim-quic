import pkg/chronos
import ./connection
import ./connectionid

type
  Listener* = ref object
    udp*: DatagramTransport
    incoming*: AsyncQueue[Connection]
    connection: Connection

proc newListener*: Listener =
  Listener(incoming: newAsyncQueue[Connection]())

proc hasConnection(listener: Listener): bool =
  not listener.connection.isNil

proc getConnection(listener: Listener): Connection =
  listener.connection

proc addConnection(listener: Listener, connection: Connection) {.async.} =
  listener.connection = connection
  await listener.incoming.put(connection)

proc getOrCreateConnection*(listener: Listener,
                            udp: DatagramTransport,
                            remote: TransportAddress):
                            Future[Connection] {.async.} =
  var connection: Connection
  if not listener.hasConnection():
    connection = newIncomingConnection(udp, remote)
    await listener.addConnection(connection)
  else:
    connection = listener.getConnection()
  result = connection
