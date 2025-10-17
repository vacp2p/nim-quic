import ../../../basics
import ../../stream
import ../native/connection
import ./queue
import ./basestate
import ./closestate
import ./receivestate
import ./sendstate

type OpenStreamState* = ref object of BaseStreamState

proc newOpenStreamState*(
    connection: Ngtcp2Connection, stream: Stream
): OpenStreamState =
  OpenStreamState(connection: connection, stream: stream, queue: initStreamQueue())

method read*(
    state: OpenStreamState
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
    state: OpenStreamState, bytes: seq[byte]
) {.async: (raises: [CancelledError, QuicError]).} =
  await procCall BaseStreamState(state).write(bytes)

method close*(state: OpenStreamState) {.async: (raises: [CancelledError, QuicError]).} =
  state.switch(newReceiveStreamState(state))

method closeWrite*(
    state: OpenStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  state.switch(newReceiveStreamState(state))

method closeRead*(
    state: OpenStreamState
) {.async: (raises: [CancelledError, QuicError]).} =
  state.switch(newSendStreamState(state))

method onClose*(state: OpenStreamState) =
  state.switch(newClosedStreamState(state))

method isClosed*(state: OpenStreamState): bool =
  false

method receive*(state: OpenStreamState, offset: uint64, bytes: seq[byte], isFin: bool) =
  state.queue.insert(offset, bytes, isFin)

method reset*(state: OpenStreamState) {.raises: [QuicError].} =
  state.switch(newClosedStreamState(state, wasReset = true))
