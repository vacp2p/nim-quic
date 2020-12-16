QUIC for Nim
============

We're working towards an implementation of the
[QUIC](https://datatracker.ietf.org/wg/quic/about/) protocol for
[Nim](https://nim-lang.org/). This is very much a work in progress, and not yet
in a usable state.

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

### Outgoing connections

Connect to a QUIC peer:

```nim
let connection = await dial(initTAddress("127.0.0.1:12345"))
```

Open a new stream:

```nim
let stream = await connection.openStream()
```

Write to the stream:

```nim
let message = cast[seq[byte]]("some message")
await stream.write(message)
```

Close stream:

```nim
await stream.close()
```

Close connection:

```nim
await connection.close()
```

### Incoming connections

Listen for incoming connections:

```nim
let listener = listen(initTAddress("127.0.0.1:12345"))
```

Accept an incoming connection:

```nim
let connection = await listener.accept()
```

Wait for an incoming stream:

```nim
let stream = await connection.incomingStream()
```

Read from a stream:

```nim
let message = await stream.read()
```

Close stream:

```nim
await stream.close()
```

Close connection:

```nim
await connection.close()
```

Stop listening:
```nim
await listener.stop()
```

Roadmap
-------

This is a rough outline of the steps that we expect to take during
implementation. They are bound to change over time.

- [ ] Wrap existing C library for QUIC, to test Nim implementation against
  - [x] Wrap C library with Nimterop
  - [x] Dummy TLS implementation
  - [x] Open connection
  - [x] Complete handshake
  - [x] Create uni-directional stream
  - [ ] Create bi-directional stream
  - [x] Send data over stream
  - [x] Close stream
  - [x] Close connection
  - [ ] Interface with real TLS library
- [ ] Integrate QUIC as a transport in [libp2p](https://github.com/status-im/nim-libp2p)
- [ ] Support IPv6 UDP addresses
- [ ] Idle timeouts
- [ ] Handle [zero-length destination ids](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-5.2)
- [x] [Packet formats](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-17)
  - [x] [Initial packets](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-17.2.2)
  - [x] [0-RTT packets](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-17.2.3)
  - [x] [Handshake packets](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-17.2.4)
  - [x] [Retry packets](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-17.2.5)
  - [x] [Version negotiation packets](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-17.2.1)
  - [x] [Short header packets](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-17.3)
- [ ] [Frames](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-12.4)
  - [ ] Initial & Handshake frames
    - [ ] [Padding](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.1)
    - [ ] [Ping](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.2)
    - [ ] [Ack](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.3)
    - [ ] [Crypto](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.6)
    - [ ] [Connection close](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.19)
    - [ ] [Handshake done](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.20)
  - [ ] Other frames
    - [ ] [Reset stream](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.4)
    - [ ] [Stop sending](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.5)
    - [ ] [New token](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.7)
    - [ ] [Stream](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.8)
    - [ ] [Max data](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.9)
    - [ ] [Max stream data](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.10)
    - [ ] [Max streams](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.11)
    - [ ] [Data blocked](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.12)
    - [ ] [Stream data blocked](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.13)
    - [ ] [Streams blocked](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.14)
    - [ ] [New connection id](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.15)
    - [ ] [Retire connection id](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.16)
    - [ ] [Path challenge](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.17)
    - [ ] [Path response](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.18)
    - [ ] [Connection close](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-19.19)
- [ ] [Connections](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-5)
  - [ ] [Outgoing (client)](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-5.2.1)
  - [ ] [Incoming (server)](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-5.2.2)
  - [ ] [Multiplexing (server)](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-5.2)
- [ ] [Handshake](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-7)
- [ ] [Streams](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-2)
  - [ ] Outgoing (writing)
  - [ ] Incoming (reading)
  - [ ] Uni-directional
  - [ ] Bi-directional
- [ ] [ACKs and retransmissions](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-13)
- [ ] [Flow control](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-4)
- [ ] [Packet encryption](https://datatracker.ietf.org/doc/html/draft-ietf-quic-tls-30#section-5)
  - [ ] Start by using dummy TLS implementation
  - [ ] Select [suitable TLS lib](https://github.com/ngtcp2/ngtcp2/blob/master/doc/programmers-guide.rst#prerequisites)
  - [ ] Integrate TLS lib
- [ ] [Loss detection](https://datatracker.ietf.org/doc/html/draft-ietf-quic-recovery-30#section-6)
- [ ] [Congestion control](https://datatracker.ietf.org/doc/html/draft-ietf-quic-recovery-30#section-7)
- [ ] [Address validation](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-8)
- [ ] [Connection migration](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-9)
- [ ] [Version negotiation](https://datatracker.ietf.org/doc/html/draft-ietf-quic-transport-30#section-6)

Thanks
------

We would like to thank the authors of the [NGTCP2](https://github.com/ngtcp2/ngtcp2) library, on whose work we're building.
