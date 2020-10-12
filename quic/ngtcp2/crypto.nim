import ngtcp2
import params

proc submitCryptoData*(connection: ptr ngtcp2_conn) =
  var cryptoData = connection.encodeTransportParameters()
  doAssert 0 == ngtcp2_conn_submit_crypto_data(
    connection,
    NGTCP2_CRYPTO_LEVEL_INITIAL,
    addr cryptoData[0],
    cryptoData.len.uint
  )

proc handleCryptoData*(connection: ptr ngtcp2_conn, data: openArray[byte]) =
  var params = decodeTransportParameters(data)
  assert 0 == ngtcp2_conn_set_remote_transport_params(connection, addr params)
