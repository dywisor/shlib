#!/bin/sh

readonly CMDPOOL_EX_NOROOT=22
readonly CMDPOOL_EX_FAILROOT=23
readonly CMDPOOL_EX_NOSLOT=24
readonly CMDPOOL_EX_FAILSLOT=25
readonly CMDPOOL_EX_BADSLOT=26
readonly CMDPOOL_EX_STARTFAIL=27
readonly CMDPOOL_EX_CMDRUNNING=28
readonly CMDPOOL_EX_NOHELPER=29


cmdpool_manage_print_help() {
   local I="   "
   echo "
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
${I}${SCRIPT_FILENAME} [option...] stopall [--exact] <name> [[--exact] <name>...]


Options:
--help          (-h) -- show this message
--debug              -- enable debug messages
--no-debug           -- disable debug messages
--cmdpool-root  (-C) -- set cmdpool root [${DEFAULT_CMDPOOL_ROOT}]
--runcmd <file> (-X) -- cmdpool runcmd helper [${DEFAULT_X_CMDPOOL_RUNCMD-}]
--names              -- print names only (one per line)
--timeout       (-t) -- timeout for the \"wait\" command, in seconds


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
${I}stopall  -- stops a series of commands (\"@all\" stops _all_ commands)


Exit codes (except for \"query returncode\"):
${I} ${EX_OK} -- success
${I} ${EX_ERR} -- unspecified error
${I}${CMDPOOL_EX_NOROOT} -- cmdpool root does not exist
${I}${CMDPOOL_EX_FAILROOT} -- failed to create the cmdpool root
${I}${CMDPOOL_EX_NOSLOT} -- no such slot
${I}${CMDPOOL_EX_FAILSLOT} -- failed to create a slot
${I}${CMDPOOL_EX_BADSLOT} -- slot directory exists, but is not a slot
${I}${CMDPOOL_EX_STARTFAIL} -- command failed to start
${I}${CMDPOOL_EX_CMDRUNNING} -- command is running
${I}${CMDPOOL_EX_NOHELPER} -- runcmd helper script is missing
${I}${EX_USAGE} -- bad usage"
}

cmdpool_manage_print_subcmd_help() {
   if [ -n "${CMDPOOL_ROOT-}" ]; then
      local DEFAULT_CMDPOOL_ROOT="${CMDPOOL_ROOT}"
   fi
   if [ -n "${X_CMDPOOL_RUNCMD-}" ]; then
      local DEFAULT_X_CMDPOOL_RUNCMD="${X_CMDPOOL_RUNCMD}"
   fi
   cmdpool_manage_print_help
}

cmdpool_manage_exit_usage() {
   die "bad usage${1:+: }${1-}" ${EX_USAGE}
}

cmdpool_need_arg_nonempty() {
   local argc=${1:?}
   local arg="${2:?}"
   shift 2
   local k=0
   while [ ${k} -lt ${argc} ] && [ ${#} -gt 0 ]; do
      case "${1}" in
         ''|-*)
            break
         ;;
      esac
      shift
      k=$(( ${k} + 1 ))
   done

   if [ ${k} -eq ${argc} ]; then
      return 0
   else
      cmdpool_manage_exit_usage "${arg} needs ${argc} non-empty args"
   fi
}

cmdpool_set_slot_name_arg() {
   if [ -n "${SLOT_NAME_ARGS+SET}" ]; then
      cmdpool_manage_exit_usage "too many args for slot name '${1}'"
   elif [ -z "${1}" ]; then
      cmdpool_manage_exit_usage "slot name must not be empty."
   else
      SLOT_NAME_ARGS="${1}"
   fi
}

# ~int cmdpool_manage_call_if_slotmatch ( slot, func, *args, **CMDPOOL_ROOT )
#
cmdpool_manage_call_if_slotmatch() {
   local slot="${1?}"
   local func="${2:?}"
   shift 2

   local name="${slot#${CMDPOOL_ROOT}/}"
   if \
      list_has "${name}" ${SLOT_NAME_ARGS-} || \
      str_startswith "${name}" ${NAME_ARGS-}
   then
      "${func}" "${slot}" "$@"
      return ${?}
   else
      return 0
   fi
}

# void cmdpool_manage_stop_if_running ( slot, *args )
#
cmdpool_manage_stop_if_running() {
   if [ -e "${1:?}/running" ] && [ ! -e "${1:?}/stopping" ]; then
      cmdpool_stop "$@" &
   fi
   return 0
}


# void cmdpool_manage_print_slot (
#    slot, **CMDPOOL_ROOT, **cmdpool_slotcount!
# )
#
cmdpool_manage_print_slot() {
   local slot="${1?}"
   local name="${slot#${CMDPOOL_ROOT}/}"
   if [ -n "${slot}" ] && [ -n "${name}" ]; then
      local status

      if [ -e "${slot}/done" ]; then

         if [ -e "${slot}/success" ]; then
            #status="DONE_SUCCESS"
            status="DS"

         elif [ -e "${slot}/running" ]; then
            #status="DONE_FAIL"
            status="DF"

         else
            #status="DONE"
            status="D_"

         fi

      elif [ -e "${slot}/running" ]; then

         #status="RUNNING"
         if [ -e "${slot}/stopping" ]; then
            status="RS"
         else
            status="R_"
         fi

      elif [ -e "${slot}/initialized" ]; then
         #status="START_FAILED"
         status="SF"

      else
         #status="INVALID"
         status='__'

      fi

      if [ -n "${status-}" ]; then
         echo "${status}" "${name}"
         [ "${status}" = "__" ] || \
            cmdpool_slotcount=$(( ${cmdpool_slotcount:-0} + 1 ))
      fi
   fi
}

# void cmdpool_manage_print_slot_names (
#    slot, **CMDPOOL_ROOT, **cmdpool_slotcount!
# )
cmdpool_manage_print_slot_names() {
   local slot="${1?}"
   local name="${slot#${CMDPOOL_ROOT}/}"
   if [ -n "${slot}" ] && [ -n "${name}" ]; then
      if \
         [ -e "${slot}/initialized" ] || \
         [ -e "${slot}/done" ] || [ -e "${slot}/running" ]
      then
         echo "${name}"
         cmdpool_slotcount=$(( ${cmdpool_slotcount:-0} + 1 ))
      fi
   fi
   return 0
}

# int cmdpool_manage_get_slot (
#    **SLOT_NAME_ARGS=, **CMDPOOL_ROOT, **CMDPOOL_COMMAND, **slot!
# )
#
cmdpool_manage_get_slot() {
   slot=
   if [ -z "${SLOT_NAME_ARGS-}" ]; then
      cmdpool_manage_exit_usage "${CMDPOOL_COMMAND}: no slot name given"
   elif [ ! -d "${CMDPOOL_ROOT}" ]; then
      return ${CMDPOOL_EX_NOROOT}
   else
      slot="${CMDPOOL_ROOT}/${SLOT_NAME_ARGS}"
      if [ ! -d "${slot}" ]; then
         return ${CMDPOOL_EX_NOSLOT}
      elif [ -e "${slot}/initialized" ]; then
         return 0
      else
         return ${CMDPOOL_EX_BADSLOT}
      fi
   fi
}

# int cmdpool_manage_check_any_running (
#    **NAME_ARGS=, **SLOT_NAME_ARGS=, **CMDPOOL_ROOT
# )
cmdpool_manage_check_any_running() {
   local slot slot_name

   if [ -n "${SLOT_NAME_ARGS-}" ]; then
      for slot_name in ${SLOT_NAME_ARGS}; do
         slot="${CMDPOOL_ROOT}/${slot_name}"
         if [ -e "${slot}/running" ]; then
            return 0
         fi
      done
   fi

   if [ -n "${NAME_ARGS-}" ]; then
      # unreachable code as there's no action that sets NAME_ARGS
      # and uses this function
      #
      # Note, however, that the list of slots is re-evaluated each time
      # this function is called.
      #
      for slot in "${CMDPOOL_ROOT}/"*; do
         if [ -e "${slot}/running" ]; then
            slot_name="${slot#${CMDPOOL_ROOT}/}"
            if str_startswith "${slot_name}" ${NAME_ARGS}; then
               return 0
            fi
         fi
      done
   fi

   return 1
}



# @funcdef @cmdpool_action int cmdpool_manage_do_<action name> (
#    *args,
#    **DEFAULT_CMDPOOL_ROOT, **CMDPOOL_ROOT, **CMDPOOL_COMMAND,
#    **NAME_ARGS=, **SLOT_NAME_ARGS=, **WANT_ALL_SLOTS=, **COMMAND_ARG=
#  )
#
#  cmdpool action function.
#

# @virtual @cmdpool_action cmdpool_manage_do_TODO()
#
cmdpool_manage_do_TODO() {
   die "'${CMDPOOL_COMMAND}' action is TODO"
}

# @cmdpool_action cmdpool_manage_do_list()
#
cmdpool_manage_do_list() {
   local cmdpool_slotcount=0
   local args
   if [ ! -d "${CMDPOOL_ROOT}" ]; then
      return ${CMDPOOL_EX_NOROOT}

   elif \
      [ -n "${NAME_ARGS+SET}${SLOT_NAME_ARGS+SET}" ] && \
      [ "${WANT_ALL_SLOTS:-n}" != "y" ]
   then
      args="cmdpool_manage_call_if_slotmatch"
   fi

   if [ "${CMDPOOL_MANAGE_LIST_NAMES_ONLY:-n}" = "y" ]; then
      args="${args-}${args:+ }cmdpool_manage_print_slot_names"
   else
      args="${args-}${args:+ }cmdpool_manage_print_slot"
   fi

   cmdpool_iter_slots "${CMDPOOL_ROOT}" "" ${args:?}

   if [ ${cmdpool_slotcount} -gt 0 ]; then
      return ${EX_OK}
   else
      return ${CMDPOOL_EX_NOSLOT}
   fi
}

# @cmdpool_action cmdpool_manage_do_ls()
#
cmdpool_manage_do_ls() {
   cmdpool_manage_do_list "$@"
}

# @cmdpool_action cmdpool_manage_do_start ( *cmdv )
#
cmdpool_manage_do_start() {
   local v0

   if [ -z "${CMDPOOL_COMMAND}" ] || [ -z "$*" ]; then
      cmdpool_manage_exit_usage "'${CMDPOOL_COMMAND}' needs a command"

   elif [ ! -x "${X_CMDPOOL_RUNCMD-}" ]; then
      cmdpool_log_error "runcmd helper script not available"
      return ${CMDPOOL_EX_NOHELPER}

   elif ! keepdir_clean "${CMDPOOL_ROOT}"; then
      return ${CMDPOOL_EX_FAILROOT}

   elif ! cmdpool_get_slot "${CMDPOOL_ROOT}" "${SLOT_NAME_ARGS-}" "$@"; then
      return ${CMDPOOL_EX_FAILSLOT}

   else
      local slot="${v0}"
      if cmdpool_do_start "${slot}" "$@"; then
         echo "${slot}"
         return ${EX_OK}
      else
         echo "${slot}"
         return ${CMDPOOL_EX_STARTFAIL}
      fi
   fi
}

# @cmdpool_action cmdpool_manage_do_run ( *cmdv )
#
cmdpool_manage_do_run() {
   cmdpool_manage_do_start "$@"
}

# @cmdpool_action cmdpool_manage_do_check()
#
cmdpool_manage_do_check() {
   local slot
   cmdpool_manage_get_slot || return ${?}

   if [ -e "${slot}/done" ]; then
      return ${EX_OK}
   elif [ -e "${slot}/running" ]; then
      return ${CMDPOOL_EX_CMDRUNNING}
   else
      return ${CMDPOOL_EX_STARTFAIL}
   fi
}

# @cmdpool_action cmdpool_manage_do_stop()
#
cmdpool_manage_do_stop() {
   local slot
   cmdpool_manage_get_slot || return ${?}
   if cmdpool_stop "${slot}" "${COMMAND_ARG-}"; then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}

# @cmdpool_action cmdpool_manage_do_query()
#
cmdpool_manage_do_query() {
   local slot
   cmdpool_manage_get_slot || return ${?}
   case "${COMMAND_ARG-}" in
      'stdout'|'stderr')
         cat "${slot}/${COMMAND_ARG}" || return ${EX_ERR}
      ;;
      'returncode')
         [ -e "${slot}/done" ] && \
            cat "${slot}/${COMMAND_ARG}" || return ${EX_ERR}
      ;;
      'slot')
         echo "${slot}"
      ;;
      *)
         die "unknow query command '${COMMAND_ARG}'"
      ;;
   esac

   return ${EX_OK}
}

# @cmdpool_action cmdpool_manage_do_wait()
#
cmdpool_manage_do_wait() {
   if \
      [ -z "${SLOT_NAME_ARGS-}" ] || [ ! -d "${CMDPOOL_ROOT}" ] || \
      ! cmdpool_manage_check_any_running
   then
      return ${EX_OK}

   elif [ -n "${WAIT_TIMEOUT-}" ]; then
      # time_elapsed in half-seconds
      local time_elapsed=0
      local timeout=$(( 2 * ${WAIT_TIMEOUT} ))

      while [ ${time_elapsed} -lt ${timeout} ] && sleep 0.5; do
         time_elapsed=$(( ${time_elapsed} + 1 ))
         cmdpool_manage_check_any_running || return ${EX_OK}
      done

      return ${CMDPOOL_EX_CMDRUNNING}

   else
      while sleep 0.5; do
         cmdpool_manage_check_any_running || return ${EX_OK}
      done
      return ${EX_ERR}
   fi
}

# @cmdpool_action cmdpool_manage_do_abandon()
#
cmdpool_manage_do_abandon() {
   local slot
   cmdpool_manage_get_slot || return ${?}
   if cmdpool_mark_for_removal "${slot}"; then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}

# @cmdpool_action cmdpool_manage_do_autodel()
#
cmdpool_manage_do_autodel() {
   cmdpool_manage_do_abandon "$@"
}

# @cmdpool_action cmdpool_manage_do_cleanup()
#
cmdpool_manage_do_cleanup() {
   local args
   if [ ! -d "${CMDPOOL_ROOT}" ]; then
      return ${CMDPOOL_EX_NOROOT}

   elif \
      [ -z "${NAME_ARGS+SET}${SLOT_NAME_ARGS+SET}" ] || \
      [ "${WANT_ALL_SLOTS:-n}" = "y" ]
   then
      args="cmdpool_remove_slot"
   else
      args="cmdpool_manage_call_if_slotmatch cmdpool_remove_slot"
   fi

   local F_CMDPOOL_ITER_ON_ERROR=true
   if cmdpool_iter_slots_with_flag \
      auto_cleanup "${CMDPOOL_ROOT}" "" ${args:?}
   then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}



# @cmdpool_action cmdpool_manage_do_stopall()
#
cmdpool_manage_do_stopall() {
   local args
   if [ ! -d "${CMDPOOL_ROOT}" ]; then
      return ${CMDPOOL_EX_NOROOT}

   elif \
      [ -z "${NAME_ARGS+SET}${SLOT_NAME_ARGS+SET}" ] || \
      [ "${WANT_ALL_SLOTS:-n}" = "y" ]
   then
      args="cmdpool_manage_stop_if_running"
   else
      args="cmdpool_manage_call_if_slotmatch cmdpool_manage_stop_if_running"
   fi

   local F_CMDPOOL_ITER_ON_ERROR=true
   cmdpool_iter_slots_with_flag running "${CMDPOOL_ROOT}" "" ${args:?}
   if wait; then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}

cmdpool_manage_main() {
   local v0
   local libdir shlib_libdir
   for libdir in /usr/lib64 /usr/lib32 /usr/lib; do
      if [ -d "${libdir}/shlib" ]; then
         shlib_libdir="${libdir}/shlib"
         break
      fi
   done
   libdir=

   [ -n "${RUNDIR-}" ] || local RUNDIR="/run"
   [ -n "${USER-}"   ] || local USER="$(id -nu)"
   local DEFAULT_CMDPOOL_ROOT="${RUNDIR}/cmdpool.${USER}/default"
   local CMDPOOL_ROOT="${DEFAULT_CMDPOOL_ROOT}"
   local CMDPOOL_COMMAND=
   if [ -n "${shlib_libdir-}" ]; then
      local DEFAULT_X_CMDPOOL_RUNCMD="${shlib_libdir}/cmdpool-runcmd.sh"
   else
      local DEFAULT_X_CMDPOOL_RUNCMD="/usr/bin/cmdpool-runcmd.sh"
   fi
   local X_CMDPOOL_RUNCMD="${DEFAULT_X_CMDPOOL_RUNCMD}"

   local NAME_ARGS
   local SLOT_NAME_ARGS
   local WANT_ALL_SLOTS
   local COMMAND_ARG
   local CMDPOOL_MANAGE_LIST_NAMES_ONLY
   local WAIT_TIMEOUT

   if [ $# -eq 0 ]; then
      cmdpool_manage_print_help
      cmdpool_manage_exit_usage "no args supplied"
   fi

   local arg doshift
   while [ $# -gt 0 ]; do
      doshift=1
      arg="${1}"

      case "${CMDPOOL_COMMAND-}" in
         '')
            case "${arg}" in
               '')
                  true
               ;;
               '--help'|'-h')
                  cmdpool_manage_print_help
                  return ${EX_OK}
               ;;
               '--debug')
                  DEBUG=y
               ;;
               '--no-debug')
                  DEBUG=n
               ;;
               '--cmdpool-root'|'-C')
                  cmdpool_need_arg_nonempty 1 "$@"
                  if get_fspath "${2}" && [ "${v0}" != "/" ]; then
                     CMDPOOL_ROOT="${v0}"
                  else
                     cmdpool_manage_exit_usage "invalid cmdpool root '${2-}'"
                  fi
                  doshift=2
               ;;
               '--runcmd'|'-X')
                  cmdpool_need_arg_nonempty 1 "$@"
                  if \
                     get_fspath "${2}" && [ -f "${v0}" ] && [ -x "${v0}" ]
                  then
                     X_CMDPOOL_RUNCMD="${v0}"
                  else
                     cmdpool_manage_exit_usage \
                        "helper script '${2-}' does not exist/cannot be executed"
                  fi
                  doshift=2
               ;;
               'ls'|'list'|'run'|'start'|'check'|'stop'|'query'|'wait'|\
               'abandon'|'autodel'|'cleanup'|'stopall')
                  CMDPOOL_COMMAND="${arg}"
               ;;
               *)
                  cmdpool_manage_exit_usage "unknown option/arg '${arg}'"
               ;;
            esac
         ;;

         'ls'|'list')
            case "${arg}" in
               '')
                  true
               ;;
               '--help'|'-h')
                  cmdpool_manage_print_subcmd_help
                  return ${EX_OK}
               ;;
               '@all')
                  WANT_ALL_SLOTS=y
               ;;
               '--exact')
                  cmdpool_need_arg_nonempty 1 "$@"
                  SLOT_NAME_ARGS="${SLOT_NAME_ARGS-}${SLOT_NAME_ARGS:+ }${2}"
                  doshift=2
               ;;
               '--names')
                  CMDPOOL_MANAGE_LIST_NAMES_ONLY=y
               ;;
               *)
                  NAME_ARGS="${NAME_ARGS-}${NAME_ARGS:+ }${1}"
               ;;
            esac
         ;;

         'run'|'start')
            case "${arg}" in
               '--help'|'-h')
                  cmdpool_manage_print_subcmd_help
                  return ${EX_OK}
               ;;
               --)
                  # command starts after --
                  : ${NAME_ARGS=}
                  shift
                  break
               ;;
               *)
                  if [ -n "${NAME_ARGS+SET}" ]; then
                     # command starts here
                     COMMAND_ARG="${arg}"
                     break
                  else
                     NAME_ARGS="${arg}"
                  fi
               ;;
            esac
         ;;

         'check'|'stop')
            case "${arg}" in
               '--help'|'-h')
                  cmdpool_manage_print_subcmd_help
                  return ${EX_OK}
               ;;
               *)
                  if [ -n "${COMMAND_ARG+SET}" ]; then
                     cmdpool_manage_exit_usage "superfluous arg '${arg}'"
                  elif [ -n "${SLOT_NAME_ARGS+SET}" ]; then
                     COMMAND_ARG="${arg}"
                  else
                     cmdpool_set_slot_name_arg "${arg}"
                  fi
               ;;
            esac
         ;;

         'query')
            case "${arg}" in
               '--help'|'-h')
                  cmdpool_manage_print_subcmd_help
                  return ${EX_OK}
               ;;
               '1'|'stdout')
                  if [ -n "${COMMAND_ARG+SET}" ]; then
                     cmdpool_set_slot_name_arg "${arg}"
                  else
                     COMMAND_ARG="stdout"
                  fi
               ;;
               '2'|'stderr')
                  if [ -n "${COMMAND_ARG+SET}" ]; then
                     cmdpool_set_slot_name_arg "${arg}"
                  else
                     COMMAND_ARG="stderr"
                  fi
               ;;
               'ret'|'returncode')
                  if [ -n "${COMMAND_ARG+SET}" ]; then
                     cmdpool_set_slot_name_arg "${arg}"
                  else
                     COMMAND_ARG="returncode"
                  fi
               ;;
               'slot')
                  if [ -n "${COMMAND_ARG+SET}" ]; then
                     cmdpool_set_slot_name_arg "${arg}"
                  else
                     COMMAND_ARG="slot_path"
                  fi
               ;;
               *)
                  if [ -n "${COMMAND_ARG+SET}" ]; then
                     cmdpool_set_slot_name_arg "${arg}"
                  else
                     cmdpool_manage_exit_usage "unknown query command '${arg}'"
                  fi
               ;;
            esac
         ;;

         'wait')
            case "${arg}" in
               '--help'|'-h')
                  cmdpool_manage_print_subcmd_help
                  return ${EX_OK}
               ;;
               '--timeout'|'-t')
                  cmdpool_need_arg_nonempty 1 "$@"
                  if is_natural "${2}"; then
                     WAIT_TIMEOUT="${2}"
                  else
                     cmdpool_manage_exit_usage "timeout has to be an int >= 0"
                  fi
                  doshift=2
               ;;
               *)
                  SLOT_NAME_ARGS="${SLOT_NAME_ARGS-}${SLOT_NAME_ARGS:+ }${arg}"
               ;;
            esac
         ;;

         'abandon'|'autodel')
            case "${arg}" in
               '--help'|'-h')
                  cmdpool_manage_print_subcmd_help
                  return ${EX_OK}
               ;;
               *)
                  cmdpool_set_slot_name_arg "${arg}"
               ;;
            esac
         ;;

         'cleanup'|'stopall')
            case "${arg}" in
               '')
                  true
               ;;
               '--help'|'-h')
                  cmdpool_manage_print_subcmd_help
                  return ${EX_OK}
               ;;
               '@all')
                  WANT_ALL_SLOTS=y
               ;;
               '--exact')
                  cmdpool_need_arg_nonempty 1 "$@"
                  SLOT_NAME_ARGS="${SLOT_NAME_ARGS-}${SLOT_NAME_ARGS:+ }${2}"
                  doshift=2
               ;;
               *)
                  NAME_ARGS="${NAME_ARGS-}${NAME_ARGS:+ }${1}"
               ;;
            esac
         ;;

         *)
            die "parser is broken (unknown \$CMDPOOL_COMMAND"
         ;;
      esac
      [ ${doshift} -lt 1 ] || shift ${doshift} || \
         die "parser is broken: out of bounds"
   done

   if [ -n "${CMDPOOL_COMMAND-}" ]; then
      cmdpool_manage_do_${CMDPOOL_COMMAND} "$@"
      return ${?}
   else
      cmdpool_manage_exit_usage "no command specified (try --help)"
   fi
}


# @imlicit int main ( *argv )
#
cmdpool_manage_main "$@"
