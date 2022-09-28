import pkg/unittest2
import pkg/ngtcp2
import pkg/stew/results
import pkg/quic/errors
import pkg/quic/transport/ngtcp2/native/connection
import pkg/quic/transport/ngtcp2/native/client
import pkg/quic/transport/ngtcp2/native/params
import ../helpers/addresses

suite "ngtcp2 transport parameters":

  var settings: ngtcp2_settings

  setup:
    ngtcp2_settings_default(addr settings)

  test "encoding and decoding":
    let encoded = encodeTransportParameters(settings.transport_params)
    let decoded = decodeTransportParameters(encoded)
    check decoded == settings.transport_params

  test "raises when decoding fails":
    var encoded = encodeTransportParameters(settings.transport_params)
    encoded[0] = 0xFF

    expect QuicError:
      discard decodeTransportParameters(encoded)

  test "raises when setting remote parameters fails":
    let connection = newNgtcp2Client(zeroAddress, zeroAddress)
    defer: connection.destroy()
    settings.transport_params.active_connection_id_limit = 0

    expect QuicError:
      let conn = connection.conn.get()
      conn.setRemoteTransportParameters(settings.transport_params)
