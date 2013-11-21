#@section functions_public

# int cmdpool_manage_run_action ( *argv, **CMDPOOL_COMMAND )
#
#  Runs a cmdpool-manage action and passes its return value.
#  Prints an error message and returns %EX_USAGE if CMDPOOL_COMMAND
#  is not set or empty.
#
cmdpool_manage_run_action() {
   if [ -n "${CMDPOOL_COMMAND-}" ]; then
      cmdpool_manage_do_${CMDPOOL_COMMAND:?} "$@"
   else
      eerror "no command specified (try --help)"
      return ${EX_USAGE}
   fi
}

# int cmdpool_manage_main ( *argv, **CMDPOOL_ARGV )
#
#  Calls cmdpool_manage_parse_args_and_dispatch ( *argv, *CMDPOOL_ARGV )
#  with cmdpool_manage_run_action() as main function.
#
cmdpool_manage_main() {
   cmdpool_manage_parse_args_and_dispatch \
      cmdpool_manage_run_action "$@" ${CMDPOOL_ARGV-}
}
