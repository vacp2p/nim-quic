type va_list {.importc, header: "<stdarg.h>".} = object

proc va_start(ap: va_list, paramN: any) {.importc, header: "<stdarg.h>".}
proc va_end(ap: va_list) {.importc, header: "<stdarg.h>".}

proc vfprintf(
  stream: File, format: cstring, arg: va_list
) {.importc, header: "<stdio.h>", varargs.}

proc fprintf(stream: File, format: cstring) {.importc, header: "<stdio.h>", varargs.}

proc log_printf*(user_data: pointer, fmt: cstring) {.varargs, cdecl.} =
  var ap: va_list

  va_start(ap, fmt)
  vfprintf(stderr, fmt, ap)
  va_end(ap)

  fprintf(stderr, "\n")
