#@section functions

# int sudofy (
#    *cmdv,
#    **USER, **SUDOFY_NOPASS=y, **SUDOFY_REEXEC=n,
#    **SUDOFY_USER=root, **SUDOFY_ONLY_OTHERS=n, **SUDO=sudo
# )
#
#  Runs cmdv as SUDOFY_USER (:= root) and passes the return value.
#  Calls cmdv directly or does nothing if USER matches SUDOFY_USER,
#  depending on SUDOFY_ONLY_OTHERS.
#
#  Replaces the current process with cmdv if SUDOFY_REEXEC is set to y.
#
#  Does not ask for a password if SUDOFY_NOPASS is set to y.
#
sudofy() {
   local CMD_PREFIX=
   [ "${SUDOFY_REEXEC:-n}" != "y" ] || CMD_PREFIX=exec

   if [ "${USER}" = "${SUDOFY_USER:-root}" ]; then
      if [ "${SUDOFY_ONLY_OTHERS:-n}" != "y" ]; then
         ${CMD_PREFIX} "$@"
      else
         return 0
      fi
   elif [ "${SUDOFY_NOPASS:-y}" = "y" ]; then
      ${CMD_PREFIX} ${SUDO:-sudo} -n -u "${SUDOFY_USER:-root}" -- "$@"
   else
      ${CMD_PREFIX} ${SUDO:-sudo} -u "${SUDOFY_USER:-root}" -- "$@"
   fi
}

# @function_alias root_please() renames sudofy()
root_please() { sudofy "$@"; }

# @noreturn|void reexec_as_user (
#    user_name, *argv,
#    **EXE=<$0>, **SUDOFY_NOPASS=y, **SUDOFY_ONLY_OTHERS=y
# )
#
#  Reexecutes this script (or EXE) as <user_name>.
#
#  Does nothing if SUDOFY_ONLY_OTHERS is set to 'y' and the user currently
#  running this script is <user_name>.
#
reexec_as_user() {
   local SUDOFY_USER="${1:?}"
   shift
   SUDOFY_REEXEC=y \
      SUDOFY_NOPASS="${SUDOFY_NOPASS:-y}" \
      SUDOFY_ONLY_OTHERS="${SUDOFY_ONLY_OTHERS:-y}" \
   sudofy "${EXE:-${0}}" "$@"
}

# @function_alias I_WANT_ROOT (...) is reexec_as_user ( "root", ... )
#
I_WANT_ROOT() { reexec_as_user root "$@"; }
