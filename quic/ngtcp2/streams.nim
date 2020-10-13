import ngtcp2
import connection
import errors

type Stream* = object
  id: int64

proc openStream*(connection: Connection): Stream =
  checkResult ngtcp2_conn_open_uni_stream(connection.conn, addr result.id, nil)
