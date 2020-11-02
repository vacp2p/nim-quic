import ngtcp2
import ../datagram
import path

type
  Connection* = ref ConnectionObj
  ConnectionObj = object
    conn*: ptr ngtcp2_conn
    path*: Path
    buffer*: array[4096, byte]
    outgoing*: seq[Datagram]

proc `=destroy`*(connection: var ConnectionObj) =
  if connection.conn != nil:
    ngtcp2_conn_del(connection.conn)
    connection.conn = nil
