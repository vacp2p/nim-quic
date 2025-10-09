import chronicles
import std/tables
import bearssl/rand
import ./basics
import ./errors
import ./connection
import ./transport/connectionid
import ./transport/parsedatagram
import ./transport/tlsbackend

type Listener* = ref object
  tlsBackend: TLSBackend
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

proc localAddress*(
    listener: Listener
): TransportAddress {.raises: [TransportOsError].} =
  listener.udp.localAddress()

proc addConnection(listener: Listener, connection: Connection, firstId: ConnectionId) =
  for id in connection.ids & firstId:
    listener.connections[id] = connection
  connection.onNewId = proc(newId: ConnectionId) =
    listener.connections[newId] = connection
  connection.onRemoveId = proc(oldId: ConnectionId) =
    listener.connections.del(oldId)
  connection.onClose = proc() {.raises: [].} =
    for id in connection.ids & firstId:
      listener.connections.del(id)
  listener.incoming.putNoWait(connection)

proc getOrCreateConnection*(
    listener: Listener,
    udp: DatagramTransport,
    msg: seq[byte],
    remote: TransportAddress,
    rng: ref HmacDrbgContext,
): Opt[Connection] {.raises: [].} =
  try:
    let destination = parseDatagramDestination(msg)
    if listener.hasConnection(destination):
      return Opt.some(listener.getConnection(destination))

    if not shouldAccept(msg):
      return Opt.none(Connection)

    let conn = newIncomingConnection(listener.tlsBackend, udp, msg, remote, rng)
    listener.addConnection(conn, destination)
    return Opt.some(conn)
  except CatchableError as e:
    # catching everything because we don't don't really care about error here - if 
    # error occurred for whichever reason `Opt.none` is returned.
    # also we don't want to import ngtcp2 errors here.
    error "Could not create connection", errorMsg = e.msg
    return Opt.none(Connection)

proc newListener*(
    tlsBackend: TLSBackend, address: TransportAddress, rng: ref HmacDrbgContext
): Listener =
  let listener = Listener(incoming: newAsyncQueue[Connection]())
  proc onReceive(
      udp: DatagramTransport, remote: TransportAddress
  ) {.async: (raises: []).} =
    try:
      let msg = udp.getMessage()
        # call getMessage() only once to avoid unnecessary allocation
      let connection = listener.getOrCreateConnection(udp, msg, remote, rng)
      if connection.isSome():
        connection.get().receive(Datagram(data: msg))
    except TransportError as e:
      error "Unexpect transport error", errorMsg = e.msg
    except QuicError as e:
      error "Failed to receive datagram", errorMsg = e.msg

  listener.tlsBackend = tlsBackend
  listener.udp = newDatagramTransport(onReceive, local = address)
  listener

proc waitForIncoming*(
    listener: Listener
): Future[Connection] {.async: (raises: [CancelledError]).} =
  await listener.incoming.get()

proc accept*(
    listener: Listener
): Future[Connection] {.async: (raises: [CancelledError, QuicError, TimeOutError]).} =
  let conn = await listener.waitForIncoming()
  await conn.waitForHandshake()
  return conn

proc stop*(listener: Listener) {.async: (raises: [CancelledError]).} =
  await listener.udp.closeWait()

proc destroy*(listener: Listener) =
  listener.tlsBackend.destroy()
