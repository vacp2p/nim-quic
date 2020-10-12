import ngtcp2
import path

type Connection* = object
  conn*: ptr ngtcp2_conn
  path*: Path

proc `=destroy`*(connection: var Connection) =
  if connection.conn != nil:
    ngtcp2_conn_del(connection.conn)
    connection.conn = nil
