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

Roadmap
-------

This is a rough outline of the steps that we expect to take during
implemenation. They are bound to change over time.

First, we're going to wrap an existing C library for QUIC, to test the future
native Nim implementation against, and to explore what a Nim API should look
like.

Wrap existing library:
- [ ] Interface with TLS library
- [ ] Open connection
- [ ] Create stream
- [ ] Send data
- [ ] Close stream
- [ ] Close connection
- [ ] Stream multiplexing
- [ ] Connection multiplexing

Then we'd like to implement QUIC in Nim itself:
- [ ] Open connection
- [ ] Create stream
- [ ] Send data
- [ ] Close stream
- [ ] Close connection
- [ ] Flow control
- [ ] Stream multiplexing
- [ ] Congestion control
- [ ] Connection multiplexing
