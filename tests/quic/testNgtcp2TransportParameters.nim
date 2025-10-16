import unittest2
import ngtcp2
import results
import std/sets
import quic/errors
import quic/helpers/rand
import quic/transport/tlsbackend
import quic/transport/ngtcp2/native/[connection, client, params, settings]
import ../helpers/addresses

suite "ngtcp2 transport parameters":
  var transport_params: ngtcp2_transport_params

  setup:
    transport_params = defaultTransportParameters()

  test "encoding and decoding":
    let encoded = encodeTransportParameters(transport_params)
    let decoded = decodeTransportParameters(encoded)
    check:
      transport_params.initial_max_streams_uni == decoded.initial_max_streams_uni
      transport_params.initial_max_stream_data_uni == decoded.initial_max_stream_data_uni
      transport_params.initial_max_streams_bidi == decoded.initial_max_streams_bidi
      transport_params.initial_max_stream_data_bidi_local ==
        decoded.initial_max_stream_data_bidi_local
      transport_params.initial_max_stream_data_bidi_remote ==
        decoded.initial_max_stream_data_bidi_remote
      transport_params.initial_max_data == decoded.initial_max_data

  test "raises when decoding fails":
    var encoded = encodeTransportParameters(transport_params)
    encoded[0] = 0xFF

    expect QuicError:
      discard decodeTransportParameters(encoded)

  test "raises when setting remote parameters fails":
    let tlsBackend = newClientTLSBackend(
      @[], @[], initHashSet[string](), Opt.none(CertificateVerifier)
    )
    let connection = newNgtcp2Client(tlsBackend.ctx, zeroAddress, zeroAddress, newRng())
    defer:
      connection.destroy()
    transport_params.active_connection_id_limit = 0

    expect QuicError:
      let conn = connection.conn.get()
      conn.setRemoteTransportParameters(transport_params)
