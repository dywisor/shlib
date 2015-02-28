#@section functions

strfeed_cmd() {
   local word
   word="${1?}"
   shift && [ $# -gt 0 ] || return

   printf "%s" "${word}" | "${@}"
}

v0_strfeed_cmd() {
   local word
   word="${1?}"
   shift && [ $# -gt 0 ] || return

   v0="$( printf "%s" "${word}" | "${@}" )"
}
