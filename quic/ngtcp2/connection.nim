import chronos
import ngtcp2
import ../datagram
import path

type
  Connection* = ref ConnectionObj
  ConnectionObj = object
    conn*: ptr ngtcp2_conn
    path*: Path
    buffer*: array[4096, byte]
    outgoing*: AsyncQueue[Datagram]
    incoming*: AsyncQueue[Stream]
    flowing*: AsyncEvent
  Stream* = object
    id*: int64
    connection*: Connection

proc `=destroy`*(connection: var ConnectionObj) =
  if connection.conn != nil:
    ngtcp2_conn_del(connection.conn)
    connection.conn = nil

proc newConnection*: Connection =
  new result
  result.outgoing = newAsyncQueue[Datagram]()
  result.incoming = newAsyncQueue[Stream]()
  result.flowing = newAsyncEvent()
  result.flowing.fire()
