# int sleeploop ( *argv, SLEEPLOOP_RETRY=INF, SLEEPLOOP_INTVL=0.1 )
#
#  Periodically executes *argv until it returns 0.
#  Gives up after SLEEPLOOP_RETRY retries with a return value of 20
#  if set, else loops forever.
#  Sleeps for SLEEPLOOP_INTVL after each unsuccessful run.
#
#  Returns 0 if successful or argv empty.
#
sleeploop() {
   if [ -z "$*" ] || "$@"; then
      # argv empty / first run succeeded
      return 0

   elif [ -n "${SLEEPLOOP_RETRY-}" ]; then

      local intvl="${SLEEPLOOP_INTVL:-0.1}" try=0

      while [ ${try} -lt ${SLEEPLOOP_RETRY} ] && sleep "${intvl}"; do
         "$@" && return 0
         try=$(( ${try} + 1 ))
      done

   else

      local intvl="${SLEEPLOOP_INTVL:-0.1}"

      while sleep "${intvl}"; do
         "$@" && return 0
      done
   fi
   return 20
}

# @function_alias sleeploop_retry ( retry_count, sleep_intvl, *argv )
#  is sleeploop (
#     *argv, **SLEEPLOOP_RETRY=retry_count, **SLEEPLOOP_INTVL=sleep_intvl
#  )
sleeploop_retry() {
   local SLEEPLOOP_RETRY="${1:?}" SLEEPLOOP_INTVL="${2:?}"
   shift 2 && sleeploop "$@"
}
