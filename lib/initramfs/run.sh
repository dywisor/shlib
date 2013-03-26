# @noreturn initramfs_die ( [message], [code] )
#
#  initramfs die() function. May start a rescue shell (in future).
#
initramfs_die() {
   if [ "${INITRAMFS_SHELL_ON_DIE:-y}" = "y" ]; then
      if [ -n "${1-}" ]; then
         eerror "${1}" "[CRITICAL]"
      fi

      ewarn "Starting a rescue shell"
      einfo ""
      einfo "If you\'re that you\'ve fixed whatever caused the problem,"
      einfo "touch /RESUME_BOOT and exit the shell."
      einfo "${0} will then continue where it failed."

      if [ -c "${CONSOLE-}" ]; then
         case "${CONSOLE-}" in
            /dev/ttyS?*)
               sh --login
            ;;
            /dev/tty?*)
               setsid sh -c "exec sh --login <${CONSOLE} >${CONSOLE} 2>${CONSOLE}"
            ;;
            *)
               sh --login
            ;;
         esac
      else
         sh --login
      fi
      [ -e /RESUME_BOOT ] || die "$@"
   else
      die "$@"
   fi
}

# @extern void autodie ( *argv, **AUTODIE )
# @extern void run     ( *argv, **AUTODIE )
#
#  Overridden via AUTODIE=irun.
#

# void irun ( *cmdv ), raises die()
#
#  Runs cmdv and logs the result. Treats failure as critical.
#
irun() {
   local rc=0
   "$@" || rc=$?
   if [ ${rc} -eq 0 ]; then
      dolog --level=INFO "command '$*' succeeded."
   else
      dolog -0 --level=CRITICAL "command '$*' returned ${rc}."
      initramfs_die "cannot recover from failure"
   fi
}

# @function_alias iron() renames irun (...)
#
#  Handy idiom.
#
iron() { irun "$@"; }

# int|void inonfatal ( *cmdv, **NONFATAL_RETURNS_VOID=n )
#
#  Runs cmdv and logs the result. Warns about failure.
#  Returns the command's return code if NONFATAL_RETURNS_VOID is not set
#  to 'y', else returns void (always 0).
#
inonfatal() {
   local rc=0
   "$@" || rc=$?
   if [ ${rc} -eq 0 ]; then
      dolog --level=DEBUG "command '$*' succeeded."
   else
      dolog -0 --level=WARN "command '$*' returned ${rc}."
   fi
   [ "${NONFATAL_RETURNS_VOID:-n}" = "y" ] || return ${rc}
}

# @implicit void main()
#
#  Sets the AUTODIE variable.
#
AUTODIE=irun
