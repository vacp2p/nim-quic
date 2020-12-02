import std/tables
import pkg/chronos
import ./connection
import ./connectionid
import ./ngtcp2

type
  Listener* = ref object
    udp*: DatagramTransport
    incoming*: AsyncQueue[Connection]
    connections: Table[ConnectionId, Connection]

proc newListener*: Listener =
  Listener(incoming: newAsyncQueue[Connection]())

proc hasConnection(listener: Listener, id: ConnectionId): bool =
  listener.connections.hasKey(id)

proc getConnection(listener: Listener, id: ConnectionId): Connection =
  listener.connections[id]

proc addConnection(listener: Listener, connection: Connection,
                   firstId: ConnectionId) {.async.} =
  connection.quic.onNewId = proc (newId: ConnectionId) =
    listener.connections[newId] = connection
  for id in connection.quic.ids & firstId:
    listener.connections[id] = connection
  await listener.incoming.put(connection)

proc getOrCreateConnection*(listener: Listener,
                            udp: DatagramTransport,
                            remote: TransportAddress):
                            Future[Connection] {.async.} =
  var connection: Connection
  let destination = parseDatagram(udp.getMessage()).destination
  if not listener.hasConnection(destination):
    connection = newIncomingConnection(udp, remote)
    await listener.addConnection(connection, destination)
  else:
    connection = listener.getConnection(destination)
  result = connection
