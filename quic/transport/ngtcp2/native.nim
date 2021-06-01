import ./native/connection
import ./native/server
import ./native/client
import ./native/handshake
import ./native/streams
import ./native/parsedatagram

export parseDatagram
export Ngtcp2Connection
export newNgtcp2Client
export newNgtcp2Server
export receive, send
export isHandshakeCompleted
export handshake
export ids
export openStream
export destroy
