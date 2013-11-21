#@section funcdef
# @funcdef @cmdpool_action int cmdpool_manage_do_<action name> (
#    *args,
#    **DEFAULT_CMDPOOL_ROOT, **CMDPOOL_ROOT, **CMDPOOL_COMMAND,
#    **NAME_ARGS=, **SLOT_NAME_ARGS=, **WANT_ALL_SLOTS=, **COMMAND_ARG=
#  )
#
#  cmdpool action function.
#

#@section vars
CMDPOOL_KNOWN_COMMANDS="check list ls query wait"


#@section functions_public

# @virtual @cmdpool_action cmdpool_manage_do_TODO(), raises die()
#
#  This actions lets to script die.
#
cmdpool_manage_do_TODO() {
   die "'${CMDPOOL_COMMAND}' action is TODO"
}


# @cmdpool_action cmdpool_manage_do_check ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_check() {
   local slot_dir
   cmdpool_manage_get_slot_dir || return ${?}

   if [ -e "${slot_dir}/done" ]; then
      return ${EX_OK}
   elif [ -e "${slot_dir}/running" ]; then
      return ${CMDPOOL_EX_CMDRUNNING}
   else
      return ${CMDPOOL_EX_STARTFAIL}
   fi
}


# @cmdpool_action cmdpool_manage_do_list()
#
cmdpool_manage_do_list() {
   cmdpool_manage_has_root || return ${?}
   local cmdpool_slotcount=0

   if [ "${CMDPOOL_MANAGE_LIST_NAMES_ONLY:-n}" = "y" ]; then
      cmdpool_manage_iter_slots cmdpool_manage_print_slot_names
   else
      cmdpool_manage_iter_slots cmdpool_manage_print_slot
   fi

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


# @cmdpool_action cmdpool_manage_do_query ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_query() {
   local slot_dir
   cmdpool_manage_get_slot_dir || return ${?}

   case "${CMDPOOL_SUBCOMMAND-}" in
      'stdout'|'stderr')
         cat "${slot_dir}/${CMDPOOL_SUBCOMMAND}" || return ${EX_ERR}
      ;;
      'returncode')
         [ -e "${slot_dir}/done" ] && \
            cat "${slot_dir}/${CMDPOOL_SUBCOMMAND}" || return ${EX_ERR}
      ;;
      'slot_dir')
         echo "${slot_dir}"
      ;;
      *)
         die "unknow query command '${CMDPOOL_SUBCOMMAND}'" ${EX_USAGE}
      ;;
   esac

   return ${EX_OK}
}


# @cmdpool_action cmdpool_manage_do_wait()
#
cmdpool_manage_do_wait() {
   if \
      [ -z "${CMDPOOL_SLOTS-}" ] || \
      ! cmdpool_manage_has_root || ! cmdpool_manage_check_any_running
   then
      return ${EX_OK}

   elif [ -n "${CMDPOOL_WAIT_TIMEOUT-}" ]; then
      # time_elapsed in half-seconds
      local time_elapsed=0
      local timeout=$(( 2 * ${CMDPOOL_WAIT_TIMEOUT} ))

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
