import ngtcp2

proc defaultSettings*: ngtcp2_settings =
  ngtcp2_settings_default(addr result)
