import pkg/chronos
import ./connection

type
  Listener* = ref object
    udp*: DatagramTransport
    incoming*: AsyncQueue[Connection]
    connection*: Connection

proc newListener*: Listener =
  Listener(incoming: newAsyncQueue[Connection]())

proc getOrCreateConnection*(listener: Listener,
                            udp: DatagramTransport,
                            remote: TransportAddress):
                            Future[Connection] {.async.} =
  if listener.connection.isNil:
    listener.connection = newIncomingConnection(udp, remote)
    await listener.incoming.put(listener.connection)
  result = listener.connection
