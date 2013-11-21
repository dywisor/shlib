#@section functions_public

# int repeat ( count, *cmdv )
#
#  Executes cmdv %count times (or until cmdv returns failure).
#
repeat() {
   local c="${1:?}" i=0
   shift
   while [ ${i} -lt ${c} ]; do
      "$@" || return
      i=$(( ${i} + 1 ))
   done
   return 0
}
