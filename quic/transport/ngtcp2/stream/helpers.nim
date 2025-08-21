import chronicles
import ../../../basics
import ../../stream
import ../native/connection

proc allowMoreIncomingBytes*(
    stream: Opt[stream.Stream], connection: Ngtcp2Connection, amount: uint64
) =
  let stream = stream.valueOr:
    return
  connection.extendStreamOffset(stream.id, amount)
  connection.send()

proc setUserData*(
    stream: Opt[stream.Stream], connection: Ngtcp2Connection, userdata: pointer
) =
  let stream = stream.valueOr:
    return
  connection.setStreamUserData(stream.id, userdata)

proc expire*(stream: Opt[stream.Stream]) =
  let stream = stream.valueOr:
    return
  stream.closed.fire()
