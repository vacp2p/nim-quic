import ngtcp2
import bearssl/rand
import tables
import ../../../basics
import ../../../helpers/sequninit
import ../../stream
import ../../timeout
import ../../connectionid
import ./path
import sets
import ./certificateverifier
import ./pendingackqueue

type TLSContext* = ref object
  context*: ptr SSL_CTX
  alpn*: HashSet[string]
  certVerifier*: Opt[CertificateVerifier]

type
  Ngtcp2Connection* = ref object
    conn*: Opt[ptr ngtcp2_conn]
    tlsContext*: TLSContext
    ssl*: ptr SSL
    connref*: ptr ngtcp2_crypto_conn_ref
    pendingAckQueues*: Table[int64, PendingAckQueue]
    blockedStreams*: Table[int64, Future[void].Raising([CancelledError])]

    path*: Path
    rng*: ref HmacDrbgContext
    flowing*: AsyncEvent
    expiryTimer*: Timeout
    onSend*: proc(datagram: Datagram) {.gcsafe, raises: [QuicError].}
    onTimeout*: proc() {.gcsafe, raises: [].}
    onIncomingStream*: proc(stream: Stream)
    onHandshakeDone*: proc()
    onNewId*: Opt[proc(id: ConnectionId)]
    onRemoveId*: Opt[proc(id: ConnectionId)]

  Ngtcp2ConnectionClosed* = object of QuicError
