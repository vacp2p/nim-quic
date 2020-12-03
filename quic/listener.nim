import std/tables
import pkg/chronos
import ./connection
import ./connectionid
import ./ngtcp2

type
  Listener* = ref object
    udp: DatagramTransport
    incoming: AsyncQueue[Connection]
    connections: Table[ConnectionId, Connection]

proc hasConnection(listener: Listener, id: ConnectionId): bool =
  listener.connections.hasKey(id)

proc getConnection(listener: Listener, id: ConnectionId): Connection =
  listener.connections[id]

proc addConnection(listener: Listener, connection: Connection,
                   firstId: ConnectionId) {.async.} =
  for id in connection.ids & firstId:
    listener.connections[id] = connection
  connection.onNewId = proc(newId: ConnectionId) =
    listener.connections[newId] = connection
  connection.onRemoveId = proc(oldId: ConnectionId) =
    listener.connections.del(oldId)
  connection.onClose = proc =
    for id in connection.ids & firstId:
      listener.connections.del(id)
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

proc newListener*(address: TransportAddress): Listener =
  let listener = Listener(incoming: newAsyncQueue[Connection]())
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let connection = await listener.getOrCreateConnection(udp, remote)
    connection.receive(udp.getMessage())
  listener.udp = newDatagramTransport(onReceive, local = address)
  listener

proc waitForIncoming*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.incoming.get()

proc stop*(listener: Listener) {.async.} =
  await listener.udp.closeWait()
