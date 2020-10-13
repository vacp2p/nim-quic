import ngtcp2
import path

type
  Connection* = ref ConnectionObj
  ConnectionObj = object
    conn*: ptr ngtcp2_conn
    path*: Path

proc `=destroy`*(connection: var ConnectionObj) =
  if connection.conn != nil:
    ngtcp2_conn_del(connection.conn)
    connection.conn = nil
