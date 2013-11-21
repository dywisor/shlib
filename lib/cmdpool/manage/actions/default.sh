#@section vars
CMDPOOL_KNOWN_COMMANDS="${CMDPOOL_KNOWN_COMMANDS?} \
abandon autodel cleanup run start stop stopall"

#@section functions_public

# @cmdpool_action cmdpool_manage_do_abandon ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_abandon() {
   local slot_dir
   cmdpool_manage_get_slot_dir || return ${?}

   if cmdpool_mark_for_removal "${slot_dir?}"; then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}


# @cmdpool_action cmdpool_manage_do_autodel ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_autodel() {
   cmdpool_manage_do_abandon "$@"
}


# @cmdpool_action cmdpool_manage_do_cleanup()
#
cmdpool_manage_do_cleanup() {
   cmdpool_manage_has_root || return ${?}

   if cmdpool_manage_iter_slots_with_flag \
      auto_cleanup cmdpool_remove_slot
   then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}


# @cmdpool_action cmdpool_manage_do_run ( *cmdv, **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_run() {
   cmdpool_manage_do_start "$@"
}


# @cmdpool_action cmdpool_manage_do_start ( *cmdv, **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_start() {
   local v0 slot

   [ -n "${CMDPOOL_COMMAND-}" ] && [ -n "$*" ] || \
      die "'${CMDPOOL_COMMAND:-%UNSET%}' needs a command" ${EX_USAGE}

   cmdpool_manage_check_get_new_slot \
      "${CMDPOOL_SINGLE_SLOT-}" "$@" || return ${?}
   slot="${v0}"

   if cmdpool_do_start "${slot}" "$@"; then
      echo "${slot}"
      return ${EX_OK}
   else
      echo "${slot}"
      return ${CMDPOOL_EX_STARTFAIL}
   fi
}


# @cmdpool_action cmdpool_manage_do_stop ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_stop() {
   local slot_dir
   cmdpool_manage_get_slot_dir || return ${?}
   if cmdpool_stop "${slot_dir}" "${CMDPOOL_SUBCOMMAND-}"; then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}


# @cmdpool_action cmdpool_manage_do_stopall()
#
cmdpool_manage_do_stopall() {

   cmdpool_manage_has_root && cmdpool_manage_has_runcmd || return ${?}

   cmdpool_manage_iter_slots_with_flag \
      running cmdpool_manage_stop_if_running

   if wait; then
      return ${EX_OK}
   else
      return ${EX_ERR}
   fi
}
