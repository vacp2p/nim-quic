import unittest
import ngtcp2
import quic/ngtcp2/params

suite "ngtcp2":

  var settings: ngtcp2_settings

  setup:
    ngtcp2_settings_default(addr settings)

  test "encoding and decoding of transport parameters":
    let encoded = encodeTransportParameters(settings.transport_params)
    let decoded = decodeTransportParameters(encoded)
    check decoded == settings.transport_params

  test "raises when decoding of transport parameters fails":
    var encoded = encodeTransportParameters(settings.transport_params)
    encoded[0] = 0xFF

    expect IOError:
      discard decodeTransportParameters(encoded)

  test "raises when setting remote transport parameters fails":
    var connection: ngtcp2_conn
    settings.transport_params.active_connection_id_limit = 0

    expect IOError:
      (addr connection).setRemoteTransportParameters(settings.transport_params)
