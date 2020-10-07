import ngtcp2

type Connection* = object
  conn*: ptr ngtcp2_conn
  path*: ngtcp2_path

proc `=destroy`*(connection: var Connection) =
  if connection.conn != nil:
    ngtcp2_conn_del(connection.conn)
  connection.conn = nil
