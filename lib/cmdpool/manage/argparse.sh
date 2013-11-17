# @funcdef void cmdpool_manage_parsefunc <function name> (
#    *argv_remainder, **arg, **argno, **doshift!, **breakpos!, **breakparse!
# ), raises die(code=**EX_USAGE)
#
#  (%argv_remainder includes %arg)
#


# int cmdpool_manage_parse_args_and_dispatch ( main_func, *argv )
#
#  Parses *argv and calls %main_func(*argv_remainder) afterwards.
#
cmdpool_manage_parse_args_and_dispatch() {
   local RUNDIR="${RUNDIR-}"
   [ -z "${USER-}" ] || local USER

   local \
      DEFAULT_CMDPOOL_ROOT CMDPOOL_ROOT \
      DEFAULT_X_CMDPOOL_RUNCMD X_CMDPOOL_RUNCMD \
      CMDPOOL_COMMAND CMDPOOL_SUBCOMMAND \
      CMDPOOL_MANAGE_LIST_NAMES_ONLY CMDPOOL_WAIT_TIMEOUT \
      CMDPOOL_SINGLE_SLOT CMDPOOL_SLOTS CMDPOOL_SLOT_BASENAMES \
      CMDPOOL_WANT_ALL_SLOTS

   autodie cmdpool_manage_defsym

   [ -n "${1-}" ] || die "broken script: no main func given" ${EX_ERR}
   local main_func="${1}"
   shift

   local arg
   local argno=0
   local doshift=0
   local breakpos=
   local breakparse=

   while \
      [ $# -gt 0 ] && [ -z "${breakpos-}" ] && [ -z "${breakparse-}" ]
   do
      doshift=1
      arg="${1}"
      argno=$(( ${argno:?} + 1 ))

      autodie cmdpool_manage_parse_options "$@"

      if [ ${doshift} -gt 0 ]; then
         shift || die "broken parser: out of bounds"
      fi
   done

   if [ -z "${main_func-}" ]; then
      die "broken script: main func disappeared." ${EX_ERR}

   elif [ "${breakparse:-_}" != "_" ]; then
      if is_natural "${breakparse}"; then
         return ${breakparse}
      else
         return ${EX_OK}
      fi

   elif [ -n "${breakpos}" ]; then
      "${main_func:?}" "$@"
   else
      "${main_func:?}"
   fi
}

# @can-override ~int cmdpool_manage_print_help(), raises die()
#
cmdpool_manage_print_help() {
   if function_defined print_help; then
      print_help
   elif function_defined cmdpool_manage_print_default_help; then
      cmdpool_manage_print_default_help
   else
      die "no help available" ${EX_ERR}
   fi
}

cmdpool_manage_command_print_help() {
   if [ -n "${CMDPOOL_ROOT-}" ]; then
      local DEFAULT_CMDPOOL_ROOT="${CMDPOOL_ROOT}"
   fi

   if [ -n "${X_CMDPOOL_RUNCMD-}" ]; then
      local DEFAULT_X_CMDPOOL_RUNCMD="${X_CMDPOOL_RUNCMD}"
   fi

   cmdpool_manage_print_help
}

# @cmdpool_manage_parsefunc cmdpool_manage_parse_options
#
cmdpool_manage_parse_options() {
   if [ "${arg}" = "--help" ] || [ "${arg}" = "-h" ]; then
      if [ -n "${CMDPOOL_COMMAND-}" ]; then
         cmdpool_manage_command_print_help
      else
         cmdpool_manage_print_help
      fi
      breakparse=y

   elif [ -z "${CMDPOOL_COMMAND-}" ]; then

      if call_if_defined_else_false parse_option "$@"; then
         return 0

      else
         case "${arg}" in
            '--debug')
               DEBUG=y
            ;;
            '--no-debug')
               DEBUG=n
            ;;
            '--cmdpool-root'|'-C')
               cmdpool_manage_set_root "${2-}"
               doshift=2
            ;;
            '--runcmd'|'-X')
               cmdpool_manage_set_runcmd "${2-}"
               doshift=2
            ;;
            '')
               true
            ;;
            *)
               if list_has "${arg}" ${CMDPOOL_KNOWN_COMMANDS?}; then
                  CMDPOOL_COMMAND="${arg}"
               else
                  die "unknown option/arg '${arg}'" ${EX_USAGE?}
               fi
            ;;
         esac
      fi

   elif function_defined \
      cmdpool_manage_parse_command_options_${CMDPOOL_COMMAND}
   then
      cmdpool_manage_parse_command_options_${CMDPOOL_COMMAND} "$@"

   else
      die "broken parser: missing option parser for ${CMDPOOL_COMMAND}"
   fi
}
