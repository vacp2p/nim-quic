import std/monotimes
import ngtcp2
import log

proc serverDefaultSettings*: ngtcp2_settings =
  result.initial_rtt = NGTCP2_DEFAULT_INITIAL_RTT
  result.transport_params.initial_max_stream_data_bidi_local = 65535
  result.transport_params.initial_max_stream_data_bidi_remote = 65535
  result.transport_params.initial_max_stream_data_uni = 65535
  result.transport_params.initial_max_data = 128 * 1024
  result.transport_params.initial_max_streams_bidi = 3
  result.transport_params.initial_max_streams_uni = 2
  result.transport_params.max_idle_timeout = 60
  result.transport_params.max_udp_payload_size = 65535
  result.transport_params.stateless_reset_token_present = 1
  result.transport_params.active_connection_id_limit = 8
  for i in 0..<NGTCP2_STATELESS_RESET_TOKENLEN:
    result.transport_params.stateless_reset_token[i] = uint8(i)

  result.initial_ts = getMonoTime().ticks.uint
  result.log_printf = log_printf

proc clientDefaultSettings*: ngtcp2_settings =
  result.initial_rtt = NGTCP2_DEFAULT_INITIAL_RTT
  result.transport_params.initial_max_stream_data_bidi_local = 65535
  result.transport_params.initial_max_stream_data_bidi_remote = 65535
  result.transport_params.initial_max_stream_data_uni = 65535
  result.transport_params.initial_max_data = 128 * 1024
  result.transport_params.initial_max_streams_bidi = 0
  result.transport_params.initial_max_streams_uni = 2
  result.transport_params.max_idle_timeout = 60
  result.transport_params.max_udp_payload_size = 65535
  result.transport_params.stateless_reset_token_present = 0
  result.transport_params.active_connection_id_limit = 8

  result.initial_ts = getMonoTime().ticks.uint
  result.log_printf = log_printf
