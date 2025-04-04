import ngtcp2
import bearssl/rand
import chronos

proc defaultSettings*(rng: ref HmacDrbgContext): ngtcp2_settings =
  ngtcp2_settings_default_versioned(NGTCP2_SETTINGS_V2, addr result)
  result.rand_ctx = ngtcp2_rand_ctx(native_handle: cast[pointer](rng))

proc defaultTransportParameters*(): ngtcp2_transport_params =
  ngtcp2_transport_params_default_versioned(NGTCP2_TRANSPORT_PARAMS_V1, addr result)
  result.initial_max_streams_uni = 128
  result.initial_max_stream_data_uni = 256 * 1024
  result.initial_max_streams_bidi = 128
  result.initial_max_stream_data_bidi_local = 256 * 1024
  result.initial_max_stream_data_bidi_remote = 256 * 1024
  result.initial_max_data = 256 * 1024
  result.max_idle_timeout = uint64(30.seconds.nanoseconds)
