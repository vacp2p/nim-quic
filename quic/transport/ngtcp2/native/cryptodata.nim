import pkg/ngtcp2
import ./params

proc submitCryptoData*(connection: ptr ngtcp2_conn,
                       level: ngtcp2_crypto_level) =
  var cryptoData = connection.encodeTransportParameters()
  doAssert 0 == ngtcp2_conn_submit_crypto_data(
    connection,
    level,
    addr cryptoData[0],
    cryptoData.len.uint
  )

proc handleCryptoData*(connection: ptr ngtcp2_conn, data: openArray[byte]) =
  let parameters = decodeTransportParameters(data)
  connection.setRemoteTransportParameters(parameters)
