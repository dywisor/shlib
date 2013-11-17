CMDPOOL_KNOWN_COMMANDS="${CMDPOOL_KNOWN_COMMANDS?} \
abandon autodel cleanup run start stop stopall"

# void cmdpool_remove_slot__virtual ( slot_dir )
#
cmdpool_remove_slot__virtual() {
   if cmdpool_check_running "${1:?}"; then
      cmdpool_log_error +view "cannot remove slot '${1}': process is running"
      : ${cleanup_retcode:=2}
   else
      cmdpool_log_error +view "not removing slot '${1}'"
      cleanup_retcode=${CMDPOOL_EX_DENIED}
   fi
   return 0
}


# @cmdpool_action cmdpool_manage_do_abandon ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_abandon() {
   local slot_dir
   cmdpool_manage_get_slot_dir || return ${?}

   cmdpool_log_error +view "not marking ${slot_dir-} for removal"
   return ${CMDPOOL_EX_DENIED}
}

# @cmdpool_action cmdpool_manage_do_autodel ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_autodel() {
   cmdpool_manage_do_abandon "$@"
}

# @cmdpool_action cmdpool_manage_do_cleanup()
#
cmdpool_manage_do_cleanup() {
   local cleanup_retcode
   cmdpool_manage_has_root || return ${?}

   if cmdpool_manage_iter_slots_with_flag \
      auto_cleanup cmdpool_remove_slot__virtual
   then
      return ${cleanup_retcode:-${EX_OK}}
   else
      return ${cleanup_retcode:-${EX_ERR}}
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

   cmdpool_log_error +view "cannot start command '${*}'"
   return ${CMDPOOL_EX_DENIED}
}

# @cmdpool_action cmdpool_manage_do_stop ( **CMDPOOL_SINGLE_SLOT )
#
cmdpool_manage_do_stop() {
   local slot_dir
   cmdpool_manage_get_slot_dir || return ${?}
   cmdpool_log_error +view "cannot stop slot '${slot_dir}'"
   return ${CMDPOOL_EX_DENIED}
}

# @cmdpool_action cmdpool_manage_do_stopall()
#
cmdpool_manage_do_stopall() {
   cmdpool_manage_has_root && cmdpool_manage_has_runcmd || return ${?}
   cmdpool_log_error +view.${CMDPOOL_COMMAND} "cannot stop commands"
}
