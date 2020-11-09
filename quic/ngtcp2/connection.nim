import chronos
import ngtcp2
import ../datagram
import path
import errors

type
  Connection* = ref ConnectionObj
  ConnectionObj = object
    conn*: ptr ngtcp2_conn
    path*: Path
    buffer*: array[4096, byte]
    outgoing*: AsyncQueue[Datagram]
    incoming*: AsyncQueue[Stream]
    flowing*: AsyncEvent
    handshake*: AsyncEvent
  Stream* = ref object
    id*: int64
    connection*: Connection
    incoming*: AsyncQueue[seq[byte]]

proc `=destroy`*(connection: var ConnectionObj) =
  if connection.conn != nil:
    ngtcp2_conn_del(connection.conn)
    connection.conn = nil

proc newConnection*(path: Path): Connection =
  new result
  result.path = path
  result.outgoing = newAsyncQueue[Datagram]()
  result.incoming = newAsyncQueue[Stream]()
  result.flowing = newAsyncEvent()
  result.handshake = newAsyncEvent()
  result.flowing.fire()

proc newStream*(connection: Connection, id: int64): Stream =
  new result
  result.connection = connection
  result.id = id
  result.incoming = newAsyncQueue[seq[byte]]()
  checkResult ngtcp2_conn_set_stream_user_data(connection.conn, id, addr result[])
