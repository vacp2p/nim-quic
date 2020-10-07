import unittest
import ngtcp2

suite "ngtcp2":

  test "default settings":
    var settings: ngtcp2_settings
    ngtcp2_settings_default(addr settings)
    check settings.transport_params.max_udp_payload_size > 0
    check settings.transport_params.active_connection_id_limit > 0
