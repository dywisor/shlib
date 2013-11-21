#@section functions_public

# void runcmd_printcmd ( *cmdv, **RUNCMD_PRINT_STDERR=y )
#
#  Prints cmdv to stderr or stdout.
#
runcmd_printcmd() {
   if [ "${RUNCMD_PRINT_STDERR:-y}" = "y" ]; then
      einfo "$*" "cmd" 1>&2
   else
      einfo "$*" "cmd"
   fi
}

# int runcmd ( *cmdv )
#
runcmd() {
   if __faking__; then
      runcmd_printcmd "$@"
   else
      "$@"
   fi
}

# int runcmd_nostdout ( *cmdv )
#
runcmd_nostdout() {
   if __faking__; then
      runcmd_printcmd "$@"
   else
      "$@" 1>${DEVNULL?}
   fi
}

# int runcmd_nostderr ( *cmdv )
#
runcmd_nostderr() {
   if __faking__; then
      runcmd_printcmd "$@"
   else
      "$@" 2>${DEVNULL?}
   fi
}

# int runcmd_quiet ( *cmdv )
runcmd_quiet() {
   if __faking__; then
      runcmd_printcmd "$@"
   else
      "$@" 1>${DEVNULL?} 2>${DEVNULL?}
   fi
}
