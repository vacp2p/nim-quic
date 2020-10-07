import ngtcp2

proc encodeTransportParameters*(connection: ptr ngtcp2_conn): seq[byte] =
  var buffer: array[4096, byte]
  var params: ngtcp2_transport_params
  connection.ngtcp2_conn_get_local_transport_params(addr params)
  let length = ngtcp2_encode_transport_params(
    addr buffer[0],
    buffer.len.uint,
    NGTCP2_TRANSPORT_PARAMS_TYPE_ENCRYPTED_EXTENSIONS,
    addr params
  )
  buffer[0..<length]

proc decodeTransportParameters*(bytes: openArray[byte]): ngtcp2_transport_params =
  assert 0 == ngtcp2_decode_transport_params(
    addr result,
    NGTCP2_TRANSPORT_PARAMS_TYPE_ENCRYPTED_EXTENSIONS,
    unsafeAddr bytes[0],
    bytes.len.uint
  )

