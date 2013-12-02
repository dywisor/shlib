#@section functions

# int check_globbing_enabled()
#
#  Returns 0 if globbing is enabled (i.e. noglob behavior is disabled),
#  else 1.
#
check_globbing_enabled() {
   [ "${-#*f}" = "${-}" ]
}

# ~int with_globbing_do ( *cmdv )
#
#  Runs %cmdv with noglob behavior disabled.
#
with_globbing_do() {
   if check_globbing_enabled; then
      "$@"
   else
      local rc
      set +f
      "$@"
      rc=${?}
      set -f
      return ${rc}
   fi
}

# ~int without_globbing_do ( *cmdv )
#
#  Runs %cmdv with noglob behavior enabled.
#
without_globbing_do() {
   if check_globbing_enabled; then
      local rc
      set -f
      "$@"
      rc=${?}
      set +f
      return ${rc}
   else
      "$@"
   fi
}
