#@section functions

# int charwise ( func, chars, [*argv] )
#
#  Runs func <char> *argv for each char in chars.
#
#  Returns on first failure.
#
charwise() {
   [[ $# -ge 2 ]] || return 0
   local func="${1:?}" word="${2-}"
   shift 2

   local -i i=0
   local c="${word:${i}:1}"
   while [[ "${c}" ]]; do
      [[ -z "${c# }" ]] || ${func} "${c}" "$@" || return
      ((i++)) || :
      c="${word:${i}:1}"
   done
   return 0
}
