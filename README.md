QUIC for Nim
============

An implementation of the [QUIC](https://datatracker.ietf.org/wg/quic/about/) protocol in [Nim](https://nim-lang.org/).

Building and testing
--------------------

Install dependencies:

```bash
nimble install -d
```

Run tests:

```bash
nimble test
```

Examples
--------

Import quic and the [chronos](https://github.com/status-im/nim-chronos)
async library:

```nim
import quic
import chronos
```

Create server:
```nim
let tlsConfig = TLSConfig.init(cert, certPrivateKey, @["alpn"], Opt.none(CertificateVerifier))
let server = QuicServer.init(tlsConfig)
```

Accept incoming connections:
```nim
let address = initTAddress("127.0.0.1:12345")
let listener = server.listen(address)
defer:
  await listener.stop()
  listener.destroy()

while true:
  let connection =
    try:
      await listener.accept()
    except CatchableError:
      return # server stopped
  let stream = await connection.incomingStream()
  
  # read or write data to stream
  let data = await stream.read()

  await stream.close()
  await connection.waitClosed()
```

Create client:
```nim
let tlsConfig = TLSConfig.init(cert, certPrivateKey, @["alpn"], Opt.none(CertificateVerifier))
let client = QuicClient.init(tlsConfig)
```

Dial server and send message:
```nim
let address = initTAddress("127.0.0.1:12345")
let connection = await client.dial(address)
defer:
  await connection.close()

let stream = await connection.openStream()
let message = cast[seq[byte]]("hello form nim quic client")
await stream.write(message)
await stream.close()
```


Thanks
------

We would like to thank the authors of the [NGTCP2](https://github.com/ngtcp2/ngtcp2) library, on whose work we're building.
