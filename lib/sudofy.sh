# int sudofy ( *cmdv, **UID, **SUDOFY_NOPASS=y, **SUDOFY_REEXEC=n )
#
#  Runs cmdv as root and passes the return value.
#  (Calls cmdv directly if UID is 0).
#  Replaces the current process with cmdv if SUDOFY_REEXEC is set to y.
#
#  Does not ask for a password if SUDOFY_NOPASS is set to y.
#
sudofy() {
   local CMD_PREFIX=
   [ "${SUDOFY_REEXEC:-n}" != "y" ] || CMD_PREFIX=exec

   if [ ${UID} -eq 0 ]; then
      ${CMD_PREFIX} "$@"
   elif [ "${SUDOFY_NOPASS:-y}" = "y" ]; then
      ${CMD_PREFIX} sudo -n -u root -- "$@"
   else
      ${CMD_PREFIX} sudo -u root -- "$@"
   fi
}

# @function_alias root_please() renames sudofy()
root_please() { sudofy "$@"; }

# @noreturn I_WANT_ROOT ( *argv, **SUDOFY_NOPASS=y, **EXE=<$0> )
#
#  Reexecutes this script (or EXE) as root. Uses sudo unless UID is 0.
#  Does not ask for a password if SUDOFY_NOPASS is set to y.
#
I_WANT_ROOT() {
   SUDOFY_REEXEC=y SUDOFY_NOPASS="${SUDOFY_NOPASS:-y}" \
      sudofy "${EXE:-${0}}" "$@"
}
