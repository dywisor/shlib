#@section functions_public

# int repeat ( count, *cmdv )
#
#  Executes cmdv %count times (or until cmdv returns failure).
#
repeat() {
   local c="${1:?}" i
   shift
   for (( i = 0; i < ${c}; i++ )); do
      "$@" || return
   done
   return 0
}
