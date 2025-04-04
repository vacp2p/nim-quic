import ngtcp2
import ./errors

type TransportParameters* = ngtcp2_transport_params

proc encodeTransportParameters*(parameters: TransportParameters): seq[byte] =
  var buffer: array[4096, byte]
  let length = ngtcp2_transport_params_encode_versioned(
    addr buffer[0], buffer.len.uint, NGTCP2_TRANSPORT_PARAMS_V1, unsafeAddr parameters
  )
  buffer[0 ..< length]

proc encodeTransportParameters*(connection: ptr ngtcp2_conn): seq[byte] =
  var parameters = connection.ngtcp2_conn_get_local_transport_params()
  encodeTransportParameters(parameters[])

proc decodeTransportParameters*(bytes: openArray[byte]): TransportParameters =
  checkResult ngtcp2_transport_params_decode_versioned(
    NGTCP2_TRANSPORT_PARAMS_V1, addr result, unsafeAddr bytes[0], bytes.len.uint
  )

proc setRemoteTransportParameters*(
    connection: ptr ngtcp2_conn, parameters: TransportParameters
) =
  let encoded = encodeTransportParameters(parameters)
  checkResult:
    ngtcp2_conn_decode_and_set_remote_transport_params(
      connection, unsafeAddr encoded[0], encoded.len.uint
    )
