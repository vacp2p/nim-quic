import chronicles
import ../../../basics
import ../../stream
import ../native/connection

proc allowMoreIncomingBytes*(
    stream: Opt[stream.Stream], connection: Ngtcp2Connection, amount: uint64
) =
  if stream.isSome:
    let stream = stream.get()
    connection.extendStreamOffset(stream.id, amount)
    connection.send()
  else:
    trace "no stream available"

proc setUserData*(
    stream: Opt[stream.Stream], connection: Ngtcp2Connection, userdata: pointer
) =
  let stream = stream.valueOr:
    return
  connection.setStreamUserData(stream.id, userdata)
