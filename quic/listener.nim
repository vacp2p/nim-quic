import std/tables
import ./basics
import ./connection
import ./transport/connectionid
import ./transport/parsedatagram

type
  Listener* = ref object
    udp: DatagramTransport
    incoming: AsyncQueue[Connection]
    connections: Table[ConnectionId, Connection]

proc connectionIds*(listener: Listener): seq[ConnectionId] =
  for id in listener.connections.keys:
    result.add(id)

proc hasConnection(listener: Listener, id: ConnectionId): bool =
  listener.connections.hasKey(id)

proc getConnection(listener: Listener, id: ConnectionId): Connection =
  listener.connections[id]

proc localAddress*(listener: Listener): TransportAddress {.
    raises: [Defect, TransportOsError].} =
  listener.udp.localAddress()

proc addConnection(listener: Listener, connection: Connection,
                   firstId: ConnectionId) =
  for id in connection.ids & firstId:
    listener.connections[id] = connection
  connection.onNewId = proc(newId: ConnectionId) =
    listener.connections[newId] = connection
  connection.onRemoveId = proc(oldId: ConnectionId) =
    listener.connections.del(oldId)
  connection.onClose = proc {.raises: [].} =
    for id in connection.ids & firstId:
      listener.connections.del(id)
  listener.incoming.putNoWait(connection)

proc getOrCreateConnection*(listener: Listener, udp: DatagramTransport,
                            remote: TransportAddress): Connection =
  var connection: Connection
  let destination = parseDatagram(udp.getMessage()).destination
  if not listener.hasConnection(destination):
    connection = newIncomingConnection(udp, remote)
    listener.addConnection(connection, destination)
  else:
    connection = listener.getConnection(destination)
  connection

proc newListener*(address: TransportAddress): Listener =
  let listener = Listener(incoming: newAsyncQueue[Connection]())
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    let connection = listener.getOrCreateConnection(udp, remote)
    connection.receive(Datagram(data: udp.getMessage()))
  listener.udp = newDatagramTransport(onReceive, local = address)
  listener

proc waitForIncoming*(listener: Listener): Future[Connection] {.async.} =
  result = await listener.incoming.get()

proc stop*(listener: Listener) {.async.} =
  await listener.udp.closeWait()
