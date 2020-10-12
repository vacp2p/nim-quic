import ngtcp2
import errors

proc encodeTransportParameters*(parameters: ngtcp2_transport_params): seq[byte] =
  var buffer: array[4096, byte]
  let length = ngtcp2_encode_transport_params(
    addr buffer[0],
    buffer.len.uint,
    NGTCP2_TRANSPORT_PARAMS_TYPE_ENCRYPTED_EXTENSIONS,
    unsafeAddr parameters
  )
  buffer[0..<length]

proc encodeTransportParameters*(connection: ptr ngtcp2_conn): seq[byte] =
  var parameters: ngtcp2_transport_params
  connection.ngtcp2_conn_get_local_transport_params(addr parameters)
  encodeTransportParameters(parameters)

proc decodeTransportParameters*(bytes: openArray[byte]): ngtcp2_transport_params =
  checkResult ngtcp2_decode_transport_params(
    addr result,
    NGTCP2_TRANSPORT_PARAMS_TYPE_ENCRYPTED_EXTENSIONS,
    unsafeAddr bytes[0],
    bytes.len.uint
  )

proc setRemoteTransportParameters*(connection: ptr ngtcp2_conn,
                                   parameters: ngtcp2_transport_params) =
  checkResult ngtcp2_conn_set_remote_transport_params(connection, unsafeAddr parameters)
