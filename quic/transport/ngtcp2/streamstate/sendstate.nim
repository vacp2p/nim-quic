import ../../../errors
import ../../../basics
import ./queue
import ./basestate
import ./closestate

type SendStreamState* = ref object of BaseStreamState

proc newSendStreamState*(base: BaseStreamState): SendStreamState =
  SendStreamState(
    connection: base.connection,
    stream: base.stream,
    queue: base.queue,
    finSent: base.finSent,
  )

method onEnter*(state: SendStreamState) {.raises: [QuicError].} =
  procCall onEnter(BaseStreamState(state))
  state.queue.close()

method read*(
    state: SendStreamState
): Future[seq[byte]] {.async: (raises: [CancelledError, QuicError]).} =
  raise newException(ClosedStreamError, "read side is closed")

method write*(
    state: SendStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  await procCall BaseStreamState(state).write(bytes)

method close*(state: SendStreamState) {.async: (raises: [CancelledError, QuicError]).} =
  state.switch(newClosedStreamState(state))

method closeWrite*(
    state: SendStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  state.switch(newClosedStreamState(state))

method closeRead*(
    stream: SendStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  discard

method onClose*(state: SendStreamState) =
  state.switch(newClosedStreamState(state))

method isClosed*(state: SendStreamState): bool =
  false

method receive*(state: SendStreamState, offset: uint64, bytes: seq[byte], isFin: bool) =
  discard

method reset*(state: SendStreamState) {.raises: [QuicError].} =
  state.switch(newClosedStreamState(state, wasReset = true))
