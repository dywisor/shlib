#!/bin/sh
#
#  Usage: <prog> slot_dir exe [args...]
#
#  Runs "exe [args...]" in a command pool slot.
#
#  This is the default runcmd helper script (X_CMDPOOL_RUNCMD,
#  cmdpool_set_runcmd()) for the commandpool module.
#
#  The slot_dir has to exist _before_ calling this script.
#

readonly __CMDPOOL_SLOT="${1:?}"
shift || exit

# int get_user_vars ( **ID_USER!, **ID_UID!, **ID_GID!, **ID_HOME! )
#
#  Uses getent to get USER/UID/GID/HOME and stores them as ID_{USER,UID,...}.
#
#  Returns 0 if successful, else 1.
#
get_user_vars() {
   local OLDIFS="${IFS}"
   local my_uid="$(id -u 2>/dev/null)"
   if [ -n "${my_uid}" ]; then
      local IFS=":"
      set -- $( getent passwd "${my_uid}" 2>/dev/null )
      IFS="${OLDIFS}"

      if [ -n "$*" ]; then
         ID_USER="${1-}"
         ID_UID="${3-}"
         ID_GID="${4-}"
         ID_HOME="${6-}"
         return 0
      else
         return 2
      fi
   else
      return 1
   fi
}


if cd "${__CMDPOOL_SLOT}"; then

   # set additional env vars
   if get_user_vars; then
      # this is primarily useful for dash/ash
      [ -n "${USER-}" ] || export USER="${ID_USER}"
      [ -n "${UID-}"  ] || export UID="${ID_UID}"
      [ -n "${GID-}"  ] || export GID="${ID_GID}"
      [ -n "${HOME-}" ] || export HOME="${ID_HOME}"
   fi

   if \
      [ -n "${USER-}" ] && [ -z "${TMPDIR-}" ] && \
      [ -d "/tmp/users/${USER}" ]
   then
      export TMPDIR="/tmp/users/${USER}"
   fi

   # load env vars (if any)
   if [ -f "${__CMDPOOL_SLOT}/env" ] && [ -s "${__CMDPOOL_SLOT}/env" ]; then
      set -a
      . "${__CMDPOOL_SLOT}/env"
      set +a
   fi

   # write environ file (drop functions / write vars only)
   printenv | \
      sed -r -e '/^(\s+|\}$|[a-zA-Z0-9_-.]+[=]\(\)\s*\{|[^=]+$)/d' \
         > "${__CMDPOOL_SLOT}/environ"

   # run command
   touch "${__CMDPOOL_SLOT}/running"
   "$@" 1>"${__CMDPOOL_SLOT}/stdout" 2>"${__CMDPOOL_SLOT}/stderr" &
   readonly CHILD_PID="$!"

   # set up traps that terminate/kill %exe
   #  _not_ propagating these signals as the "update status" code below
   #   should always be run
   #
   trap "kill -15 ${CHILD_PID}" TERM
   trap "kill -9  ${CHILD_PID}" KILL

   echo "${CHILD_PID}" > "${__CMDPOOL_SLOT}/child_pid"

   # wait until command is done (stops, gets terminated or killed, ...)
   #
   wait "${CHILD_PID}"
   readonly RETCODE="${?}"
   trap - KILL

   # update status
   trap "" TERM
   rm -f "${__CMDPOOL_SLOT}/running"
   echo "${RETCODE}" > "${__CMDPOOL_SLOT}/returncode"

   if [ ${RETCODE} -eq 0 ]; then
      touch "${__CMDPOOL_SLOT}/success"
   else
      touch "${__CMDPOOL_SLOT}/fail"
   fi
   date +%s > "${__CMDPOOL_SLOT}/done"
   rm -f "${__CMDPOOL_SLOT}/stopping"
   trap - TERM
else
   readonly RETCODE=230
fi

exit ${RETCODE:-254}
