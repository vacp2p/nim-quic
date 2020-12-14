import pkg/chronos

proc asyncLoop*(repeat: proc: Future[void] {.gcsafe.}): Future[void] {.async.} =
  ## Repeatedly calls the async proc `repeat` until cancelled.
  ## Any `Error`s that are raised in `repeat` are considered fatal and therefore
  ## re-raised as `Defect`s.
  while true:
    try:
      await repeat()
    except CancelledError:
      raise
    except CatchableError as error:
      raise newException(FutureDefect, error.msg)
