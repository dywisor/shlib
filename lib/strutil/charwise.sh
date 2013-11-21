#@section functions

# int charwise ( func, chars, [*argv] )
#
#  Runs func <char> *argv for each char in chars.
#
#  Returns on first failure.
#
charwise() {
   [ $# -ge 2 ] || return 0
   local func="${1:?}" chars="${2-}" c
   shift 2

   # using fold is safer and faster, but it could be unavailable in
   # initramfs systems (busybox et al.)
   if qwhich fold; then
      for c in $(echo "${chars}" | fold -w1); do
         [ -z "${c# }" ] || ${func} "${c}" "$@" || return
      done
   else
      c=$(echo "${chars}" | cut -c 1)
      while [ -n "${chars}" ]; do
         [ -z "${c# }" ] || ${func} "${c}" "$@" || return
         chars="${chars#${c}}"
         c=$(echo "${chars}" | cut -c 1)
      done
   fi
   return 0
}
