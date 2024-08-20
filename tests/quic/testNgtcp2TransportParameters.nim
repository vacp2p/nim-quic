import pkg/unittest2
import pkg/ngtcp2
import pkg/stew/results
import pkg/quic/errors
import pkg/quic/transport/ngtcp2/native/connection
import pkg/quic/transport/ngtcp2/native/client
import pkg/quic/transport/ngtcp2/native/params
import pkg/quic/transport/ngtcp2/native/settings
import ../helpers/addresses

suite "ngtcp2 transport parameters":

  var transport_params: ngtcp2_transport_params

  setup:
    transport_params = defaultTransportParameters()

  test "encoding and decoding":
    let encoded = encodeTransportParameters(transport_params)
    let decoded = decodeTransportParameters(encoded)
    check decoded == transport_params

  test "raises when decoding fails":
    var encoded = encodeTransportParameters(transport_params)
    encoded[0] = 0xFF

    expect QuicError:
      discard decodeTransportParameters(encoded)

  test "raises when setting remote parameters fails":
    let connection = newNgtcp2Client(zeroAddress, zeroAddress)
    defer: connection.destroy()
    transport_params.active_connection_id_limit = 0

    expect QuicError:
      let conn = connection.conn.get()
      conn.setRemoteTransportParameters(transport_params)
