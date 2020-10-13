import ngtcp2

proc defaultSettings*: ngtcp2_settings =
  ngtcp2_settings_default(addr result)
  result.transport_params.initial_max_streams_uni = 128
