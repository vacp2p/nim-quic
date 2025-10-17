import ../../../errors
import ../../../basics
import ./queue
import ./basestate
import ./closestate

type ReceiveStreamState* = ref object of BaseStreamState

proc newReceiveStreamState*(base: BaseStreamState): ReceiveStreamState =
  ReceiveStreamState(
    connection: base.connection,
    stream: base.stream,
    queue: base.queue,
    finSent: base.finSent,
  )

method onEnter*(state: ReceiveStreamState) {.raises: [QuicError].} =
  procCall onEnter(BaseStreamState(state))
  state.sendFin()

method read*(
    state: ReceiveStreamState
): Future[seq[byte]] {.async: (raises: [CancelledError, QuicError]).} =
  # Check for immediate EOF conditions
  if state.queue.isEOF() and state.queue.incoming.len == 0:
    return @[] # Return EOF immediately per RFC 9000 "Data Read" state

  let data = await state.queue.incoming.get()

  # If we got data, return it with flow control update
  if data.len > 0:
    state.allowMoreIncomingBytes(data.len.uint64)
    return data

  # Empty data (len == 0) and this is EOF
  if state.queue.isEOF():
    return @[] # Return EOF per RFC 9000

  # Empty data but no EOF; continue reading for more data
  return await state.read()

method write*(
    state: ReceiveStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  raise newException(ClosedStreamError, "write side is closed")

method close*(
    state: ReceiveStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  state.switch(newClosedStreamState(state))

method closeWrite*(
    state: ReceiveStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  discard

method closeRead*(
    state: ReceiveStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  state.switch(newClosedStreamState(state))

method onClose*(state: ReceiveStreamState) =
  state.switch(newClosedStreamState(state))

method isClosed*(state: ReceiveStreamState): bool =
  false

method receive*(
    state: ReceiveStreamState, offset: uint64, bytes: seq[byte], isFin: bool
) =
  state.queue.insert(offset, bytes, isFin)
  if state.queue.isEOF():
    state.switch(newClosedStreamState(state))

method reset*(state: ReceiveStreamState) {.raises: [QuicError].} =
  state.switch(newClosedStreamState(state, wasReset = true))
