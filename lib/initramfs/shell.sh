# int initramfs_launch_shell ( cmd_prefix=, shell_exe=**SHELL, **CONSOLE )
#
#  Starts a shell (default: /bin/sh).
#
initramfs_launch_shell() {
   local shell="${2:-${SHELL:?}}"

   if [ -c "${CONSOLE-}" ]; then
      case "${CONSOLE-}" in
         /dev/ttyS?*)
            ${1-} ${shell} --login
         ;;
         /dev/tty?*)
            ${1-} setsid sh -c \
               "exec ${shell} --login <${CONSOLE} >${CONSOLE} 2>${CONSOLE}"
         ;;
         *)
            ${1-} ${shell} --login
         ;;
      esac
   else
      ${1-} ${shell} --login
   fi
}

# @noreturn initramfs_launch_user_shell()
#
#  Execs into $SHELL.
#
initramfs_launch_user_shell() {
   einfo "Starting shell on user request ('doshell')"
   initramfs_launch_shell exec
}


# int initramfs_launch_rescue_shell ( error_msg ), raises initramfs_die()
#
#  Starts a rescue shell. Tries to resume the boot process after shell exit.
#  Dies if resuming was not possible, else returns 0.
#  Returns non-zero if the actual die() function returned (due to overridden
#  die() function, e.g. via **F_DIE).
#
initramfs_launch_rescue_shell() {
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

   initramfs_launch_shell
   initramfs_try_resume "$@"
}

# int initramfs_shell_try_resume ( [message], [code] ), raises die()
#
#  Tries to resume the boot process after rescue shell return.
#
initramfs_shell_try_resume() {
   if [ ! -e /RESUME_BOOT ]; then

      initramfs_telinit
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
}

# int initramfs_telinit()
#
#  Searches for telinit and executes it.
#
#  Note: telinit is expected to tear down some things, reboot/... is done
#        manually
#
initramfs_telinit() {
   if [ -n "${TELINIT-}" ] && [ -x "${TELINIT}" ]; then
      ${TELINIT} --
   elif [ -x /telinit ]; then
      /telinit --
   elif [ -x /sh/telinit ]; then
      /sh/telinit --
   else
      dolog_info -0 "telinit not found, using builtin variant."

      sync
      [ ! -e /proc/swaps ] || swapoff -a
      umount -n -a -r
   fi
   return 0
}
