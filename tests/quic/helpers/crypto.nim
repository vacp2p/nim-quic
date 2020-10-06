import ngtcp2
import params

proc submitCryptoData*(connection: ptr ngtcp2_conn) =
  var cryptoData = connection.encodeTransportParameters()
  assert 0 == ngtcp2_conn_submit_crypto_data(
    connection,
    NGTCP2_CRYPTO_LEVEL_INITIAL,
    addr cryptoData[0],
    cryptoData.len.uint
  )
