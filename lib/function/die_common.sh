#@section functions

# @private @noreturn die__function ( function_name, message=, code=3 )
#
#  Common functionality for function_die().
#  Calls die( function_name~message, code ).
#
die__function() {
   if [ -n "${2:-}" ]; then
      die "while executing function ${1%()}(): ${2}" ${3:-3}
   else
      die "while executing function ${1%()}()." ${3:-3}
   fi
}
