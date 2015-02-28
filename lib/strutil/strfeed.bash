#@section functions

strfeed_cmd() {
   local word
   word="${1?}"

   shift && [ $# -gt 0 ] || return
   "${@}" <<< "${1}"
}

v0_strfeed_cmd() {
   local word
   word="${1?}"

   shift && [ $# -gt 0 ] || return
   v0="$( "${@}" <<< "${1}" )"
}
