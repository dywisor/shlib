# @noreturn initramfs_die ( [message], [code] )
#
#  initramfs die() function. May start a rescue shell (in future).
#
initramfs_die() {
   if [ -n "${F_INITRAMFS_DIE-}" ]; then

      ${F_INITRAMFS_DIE} "$@"

   elif [ "${INITRAMFS_SHELL_ON_DIE:-y}" = "y" ]; then
      if [ -n "${1-}" ]; then
         eerror "${1}" "[CRITICAL]"
      fi

      ewarn "Starting a rescue shell"
      einfo ""
      einfo "If you're sure that you've fixed whatever caused the problem,"
      einfo "touch /RESUME_BOOT and exit the shell."
      einfo "${0} will then continue where it failed."
      einfo ""
      einfo "The /RESUME_BOOT file can also be used to inject variables,"
      einfo "which may be required to continue booting."

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
      if [ ! -e /RESUME_BOOT ]; then

         [ ! -x /telinit ] || /telinit --
         die "$@"
         return 150

      elif [ -f /RESUME_BOOT ] && [ -s /RESUME_BOOT ]; then

         # read the file twice to ensure that it's actually parseable
         if ( . /RESUME_BOOT --; ) && . /RESUME_BOOT --; then
            mv -f /RESUME_BOOT /RESUME_BOOT.last
         else
            initramfs_die "errors occured while reading /RESUME_BOOT"
         fi
         return 0
      else
         mv -f /RESUME_BOOT /RESUME_BOOT.last
         return 0
      fi
   else
      [ ! -x /telinit ] || /telinit --
      die "$@"
   fi
   return 150
}

# int initramfs_assert ( *test_condition ), raises initramfs_die()
#
#  Calls test ( *test_condition ) and raises initramfs_die() if the result
#  is not 0.
#
initramfs_assert() {
   if test "$@"; then
      return 0
   else
      initramfs_die "an assertion failed: test $*"
      ## initramfs_die could return
      return 1
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

# int inonfatal ( *cmdv )
#
#  Runs cmdv and logs the result. Warns about failure.
#
#  Returns the command's return code.
#
inonfatal() {
   local rc=0
   "$@" || rc=$?
   if [ ${rc} -eq 0 ]; then
      dolog --level=DEBUG "command '$*' succeeded."
   else
      dolog -0 --level=WARN "command '$*' returned ${rc}."
   fi
   return ${rc}
}

# @implicit void main()
#
#  Sets the AUTODIE variable.
#
AUTODIE=irun
