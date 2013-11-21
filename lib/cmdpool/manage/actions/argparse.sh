#@section functions

cmdpool_manage_print_default_help() {
   local I="   "

   if function_defined print_usage_help; then
      print_usage_help "${I}"

   else
      echo "\
${SCRIPT_NAME} - manage command pools

start/stop/list/query commands running in a command pool

Usage:
${I}${SCRIPT_FILENAME} [option...] list|ls   [--names] {[--exact] <name>}
${I}${SCRIPT_FILENAME} [option...] run|start [<name>] [--] command [arg...]
${I}${SCRIPT_FILENAME} [option...] check     <slot name> [command]
${I}${SCRIPT_FILENAME} [option...] stop      <slot name> [command]
${I}${SCRIPT_FILENAME} [option...] query
${I}${I}1|2|ret|stdout|stderr|returncode|slot <slot name>
${I}${SCRIPT_FILENAME} [option...] wait [-t|--timeout <timeout>] {<slot name>}
${I}${SCRIPT_FILENAME} [option...] abandon|autodel <slot name>
${I}${SCRIPT_FILENAME} [option...] cleanup {[--exact] <name>}
${I}${SCRIPT_FILENAME} [option...] stopall [--exact] <name> [[--exact] <name>...]"

      call_if_defined print_additional_usage_help "${I}"
   fi


   if function_defined print_option_help; then
      print_option_help "${I}"

   else
      echo "


Options:
--help          (-h) -- show this message
--debug              -- enable debug messages
--no-debug           -- disable debug messages
--cmdpool-root  (-C) -- set cmdpool root [${DEFAULT_CMDPOOL_ROOT}]
--runcmd <file> (-X) -- cmdpool runcmd helper [${DEFAULT_X_CMDPOOL_RUNCMD-}]
--names              -- print names only (one per line)
--timeout       (-t) -- timeout for the \"wait\" command, in seconds"

      call_if_defined print_additional_option_help "${I}"
   fi


   if function_defined print_action_help; then
      print_action_help "${I}"

   else
      echo "


Actions:
${I}list     -- shows the status of all commands starting with the given name
${I}run,     -- starts a command using <name> as the slot's basename.
${I}start       Prints <slot name> to stdout (as last line).
${I}check    -- checks whether the command (specified by the given slot name)
${I}            is still running and exits non-zero if so (see Exit Codes).
${I}stop     -- stops a command (specified by the given slot name)
${I}query    -- prints information about a command (its location, stdout,
${I}            stderr, returncode) to stdout.
${I}wait     -- waits for a series of commands (specified by their slot names)
${I}            to complete. Waits forever unless a --timeout (in seconds) is
${I}            specified. An exit code of ${EX_OK} indicates that none of
${I}            the given command slots is running, even if the cmdpool root
${I}            does not exist, whereas ${CMDPOOL_EX_CMDRUNNING} \
means that at least one command
${I}            is still running.
${I}abandon, -- marks a slot for auto-removal
${I}autodel
${I}cleanup  -- removes all slots that are marked for auto-removal
${I}stopall  -- stops a series of commands (\"@all\" stops _all_ commands)"


      call_if_defined print_additional_action_help "${I}"
   fi


   if function_defined print_exit_code_help; then
      print_exit_code_help "${I}"

   else
      echo "


Exit codes (except for \"query returncode\"):
${I} ${EX_OK} -- success
${I} ${EX_ERR} -- unspecified error
${I}${CMDPOOL_EX_DENIED} -- command forbidden
${I}${CMDPOOL_EX_NOROOT} -- cmdpool root does not exist
${I}${CMDPOOL_EX_FAILROOT} -- failed to create the cmdpool root
${I}${CMDPOOL_EX_NOSLOT} -- no such slot
${I}${CMDPOOL_EX_FAILSLOT} -- failed to create a slot
${I}${CMDPOOL_EX_BADSLOT} -- slot directory exists, but is not a slot
${I}${CMDPOOL_EX_STARTFAIL} -- command failed to start
${I}${CMDPOOL_EX_CMDRUNNING} -- command is running
${I}${CMDPOOL_EX_NOHELPER} -- runcmd helper script is missing
${I}${EX_USAGE} -- bad usage"

      call_if_defined print_additional_exit_code_help "${I}"
   fi
   return 0
}


cmdpool_manage_parse_command_options_abandon() {
   cmdpool_manage_set_slot "${arg}"
}

cmdpool_manage_parse_command_options_autodel() {
   cmdpool_manage_parse_command_options_abandon "$@"
}

cmdpool_manage_parse_command_options_check() {
   if [ -n "${CMDPOOL_SUBCOMMAND+SET}" ]; then
      die "unknown option/arg '${arg}'" ${EX_USAGE?}
   elif [ -z "${CMDPOOL_SINGLE_SLOT-}" ]; then
      cmdpool_manage_set_slot "${arg}"
   else
      CMDPOOL_SUBCOMMAND="${arg}"
   fi
}

cmdpool_manage_parse_command_options_cleanup() {
   case "${arg}" in
      '')
         true
      ;;
      '@all')
         CMDPOOL_WANT_ALL_SLOTS=y
      ;;
      '--exact')
         cmdpool_manage_add_slots "${2-}"
         doshift=2
      ;;
      *)
         cmdpool_manage_add_slot_basenames "${arg}"
      ;;
   esac
}

cmdpool_manage_parse_command_options_list() {
   case "${arg}" in
      '')
         true
      ;;
      '@all')
         CMDPOOL_WANT_ALL_SLOTS=y
      ;;
      '--exact')
         cmdpool_manage_add_slots "${2-}"
         doshift=2
      ;;
      '--names')
         CMDPOOL_MANAGE_LIST_NAMES_ONLY=y
      ;;
      *)
         cmdpool_manage_add_slot_basenames "${arg}"
      ;;
   esac
}

cmdpool_manage_parse_command_options_ls() {
   cmdpool_manage_parse_command_options_list "$@"
}

cmdpool_manage_parse_command_options_query() {
   if [ -n "${CMDPOOL_SUBCOMMAND+SET}" ]; then
      cmdpool_manage_set_slot "${arg}"
   else
      case "${arg}" in
         '1'|'stdout')
            CMDPOOL_SUBCOMMAND="stdout"
         ;;
         '2'|'stderr')
            CMDPOOL_SUBCOMMAND="stderr"
         ;;
         'ret'|'returncode')
            CMDPOOL_SUBCOMMAND="returncode"
         ;;
         'slot')
            CMDPOOL_SUBCOMMAND="slot_dir"
         ;;
         *)
            die "unknown query command '${arg}'" ${EX_USAGE?}
         ;;
      esac
   fi
}

cmdpool_manage_parse_command_options_run() {
   cmdpool_manage_parse_command_options_start "$@"
}

cmdpool_manage_parse_command_options_start() {
   case "${arg}" in
      --)
         # command starts after --
         : ${CMDPOOL_SLOT_BASENAMES=}
         breakpos=$(( ${argno:?} + 1 ))
         CMDPOOL_SUBCOMMAND="${2-}"
      ;;
      *)
         if [ -z "${CMDPOOL_SINGLE_SLOT-}" ]; then
            cmdpool_manage_set_slot "${arg}"
         else
            breakpos=${argno:?}
            CMDPOOL_SUBCOMMAND="${arg}"
            doshift=0
         fi
      ;;
   esac
}

cmdpool_manage_parse_command_options_stop() {
   cmdpool_manage_parse_command_options_check "$@"
}

cmdpool_manage_parse_command_options_stopall() {
   cmdpool_manage_parse_command_options_cleanup "$@"
}

cmdpool_manage_parse_command_options_wait() {
   case "${arg}" in
      '--timeout'|'-t')
         if is_natural "${2-}"; then
            CMDPOOL_WAIT_TIMEOUT="${2}"
         else
            die "${arg}: timeout has to be an int >= 0" ${EX_USAGE?}
         fi
         doshift=2
      ;;
      '')
         true
      ;;
      *)
         cmdpool_manage_add_slots "${arg}"
      ;;
   esac
}
