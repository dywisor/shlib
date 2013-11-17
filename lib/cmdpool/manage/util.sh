
# int cmdpool_manage_create_root ( **CMDPOOL_ROOT )
#
#  Returns 0 if the cmdpool root directory exists "after" calling this
#  function, %CMDPOOL_EX_NOROOT if %CMDPOOL_ROOT is not set or empty,
#  and %CMDPOOL_EX_FAILROOT otherwise.
#
cmdpool_manage_create_root() {
   if [ -z "${CMDPOOL_ROOT-}" ]; then
      return ${CMDPOOL_EX_NOROOT}
   elif keepdir_clean "${CMDPOOL_ROOT}"; then
      return 0
   else
      return ${CMDPOOL_EX_FAILROOT}
   fi
}

# int cmdpool_manage_get_slot_dir (
#    slot_name=**CMDPOOL_SINGLE_SLOT=**CMDPOOL_SLOTS=,
#    **CMDPOOL_ROOT, **CMDPOOL_COMMAND="error", **slot_dir!
# ), raises die()
#
#  Determines the slot directory of the given %slot_name and returns it
#  via the %slot_dir variable.
#
#  Dies if no slot name given.
#
#  Returns 0 if %slot_dir actually is a slot dir,
#  else non-zero (CMDPOOL_EX_NOROOT, CMDPOOL_EX_NOSLOT or CMDPOOL_EX_BADSLOT).
#
cmdpool_manage_get_slot_dir() {
   local slot_name="${1:-${CMDPOOL_SINGLE_SLOT:-${CMDPOOL_SLOTS-}}}"
   slot_dir=

   if [ -z "${slot_name-}" ]; then
      die "${CMDPOOL_COMMAND:-error}: no slot name given" ${EX_USAGE?}

   elif cmdpool_manage_has_root; then
      slot_dir="${CMDPOOL_ROOT}/${slot_name}"

      if [ ! -d "${slot_dir}" ]; then
         return ${CMDPOOL_EX_NOSLOT}

      elif [ -e "${slot_dir}/initialized" ]; then
         return 0

      else
         return ${CMDPOOL_EX_BADSLOT}
      fi

   else
      return ${CMDPOOL_EX_NOROOT}
   fi
}

# int cmdpool_manage_get_new_slot ( slot_name, *cmdv, **CMDPOOL_ROOT, **v0! )
#
#  Creates a new slot and returns it via %v0.
#  Returns 0 on success, else CMDPOOL_EX_FAILSLOT.
#
cmdpool_manage_get_new_slot() {
   : ${1?} ${2?}
   if cmdpool_get_slot "${CMDPOOL_ROOT}" "$@"; then
      return 0
   else
      return ${CMDPOOL_EX_FAILSLOT}
   fi
}

# int cmdpool_manage_check_get_new_slot (
#    slot_name, *cmdv, **CMDPOOL_ROOT, **v0!
# )
#
#  Calls cmdpool_manage_get_new_slot() if essential preconditions are met
#  (cmdpool_manage_create_root() and cmdpool_manage_has_runcmd()), else
#  returns non-zero.
#
cmdpool_manage_check_get_new_slot() {
   v0=
   cmdpool_manage_create_root && \
   cmdpool_manage_has_runcmd  && \
   cmdpool_manage_get_new_slot "$@"
}

# ~int cmdpool_manage_call_if_slotmatch (
#    slot, func, *args,
#    **CMDPOOL_SINGLE_SLOT=, **CMDPOOL_SLOTS=, **CMDPOOL_SLOT_BASENAMES=,
#    **CMDPOOL_ROOT
# )
#
#  Calls %func( %slot, *args ) if slot matches an entry in
#  %CMDPOOL_SLOT_BASENAMES or appears in %CMDPOOL_SINGLE_SLOT/%CMDPOOL_SLOTS.
#
#  Returns the function's return code (if slot matched), else 0.
#
cmdpool_manage_call_if_slotmatch() {
   local slot="${1?}"
   local func="${2:?}"
   shift 2

   local name="${slot#${CMDPOOL_ROOT%/}/}"
   if \
      list_has "${name}" ${CMDPOOL_SLOTS-} ${CMDPOOL_SINGLE_SLOT-} || \
      str_startswith "${name}" ${CMDPOOL_SLOT_BASENAMES-}
   then
      "${func}" "${slot}" "$@"
      return ${?}
   else
      return 0
   fi
}

# int cmdpool_manage_check_any_running (
#    **CMDPOOL_SINGLE_SLOT=, **CMDPOOL_SLOTS=, **CMDPOOL_SLOT_BASENAMES=,
#    **CMDPOOL_ROOT
# )
#
#  Returns 0 if any slot (specified by the slot variables) is running,
#  else 1.
#
cmdpool_manage_check_any_running() {
   local slot slot_name

   if \
      [ -n "${CMDPOOL_SINGLE_SLOT-}" ] && \
      [ -e "${CMDPOOL_ROOT}/${CMDPOOL_SINGLE_SLOT}/running" ]
   then
      return 0
   fi

   if [ -n "${CMDPOOL_SLOTS-}" ]; then
      for slot_name in ${CMDPOOL_SLOTS-}; do
         slot="${CMDPOOL_ROOT}/${slot_name}"
         if [ -e "${slot}/running" ]; then
            return 0
         fi
      done
   fi

   if [ -n "${CMDPOOL_SLOT_BASENAMES-}" ]; then
      # Note that the list of slots is re-evaluated each time this function
      # is called.
      #
      for slot in "${CMDPOOL_ROOT}/"*; do
         if [ -e "${slot}/running" ]; then
            slot_name="${slot#${CMDPOOL_ROOT}/}"
            if str_startswith "${slot_name}" ${CMDPOOL_SLOT_BASENAMES}; then
               return 0
            fi
         fi
      done
   fi

   return 1
}

# @function_alias cmdpool_manage_check_none_running(...)
#  is negated cmdpool_manage_check_any_running()
#
cmdpool_manage_check_none_running() {
   ! cmdpool_manage_check_any_running "$@"
}

# void cmdpool_manage_stop_if_running ( slot, *args )
#
#  Stops a slot in background.
#
cmdpool_manage_stop_if_running() {
   if [ -e "${1:?}/running" ] && [ ! -e "${1:?}/stopping" ]; then
      cmdpool_stop "$@" &
   fi
   return 0
}

# void cmdpool_manage_print_slot_names (
#    slot, **CMDPOOL_ROOT, **cmdpool_slotcount!
# )
#
#  Prints slot's name to stdout and increases the slot counter.
#
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

# void cmdpool_manage_print_slot (
#    slot, **CMDPOOL_ROOT, **cmdpool_slotcount!
# )
#
#  Prints slot's status and name to stdout and increases the slot counter.
#
cmdpool_manage_print_slot() {
   local slot="${1?}"
   local name="${slot#${CMDPOOL_ROOT%/}/}"

   if [ -n "${slot}" ] && [ -n "${name}" ]; then
      local status

      if [ -e "${slot}/done" ]; then

         if [ -e "${slot}/success" ]; then
            status="DS"
         elif [ -e "${slot}/stopped" ]; then
            status="DH"
         elif [ -e "${slot}/fail" ]; then
            status="DF"
         else
            status="D_"
         fi

      elif [ -e "${slot}/running" ]; then

         if [ -e "${slot}/stopping" ]; then
            status="RH"
         else
            status="R_"
         fi

      elif [ -e "${slot}/initialized" ]; then
         status="SF"
      else
         status='__'
      fi

      if [ -n "${status-}" ]; then
         echo "${status}" "${name}"
         [ "${status}" = "__" ] || \
            cmdpool_slotcount=$(( ${cmdpool_slotcount:-0} + 1 ))
      fi
   fi
   return 0
}


# void cmdpool_manage_iter_slots ( func, *argv, **CMDPOOL_ROOT )
#
#  Calls %func( slot, *argv ) for all requested slots.
#
#  See cmdpool_manage_want_all_slots(), cmdpool_manage_call_if_slotmatch()
#  and cmdpool_iter_slots() (from cmdpool/core) for details.
#
cmdpool_manage_iter_slots() {
   local F_CMDPOOL_ITER_ON_ERROR=true

   if cmdpool_manage_want_all_slots; then
      cmdpool_iter_slots "${CMDPOOL_ROOT}" "" "$@"
   else
      cmdpool_iter_slots "${CMDPOOL_ROOT}" "" \
         cmdpool_manage_call_if_slotmatch "$@"
   fi
}

# void cmdpool_manage_iter_slots_with_flag (
#    flag, func, *argv, **CMDPOOL_ROOT
# )
#
#  Calls %func( slot, *argv ) for all requested slots with the given flag.
#
#  See cmdpool_manage_want_all_slots(), cmdpool_manage_call_if_slotmatch()
#  and cmdpool_iter_slots_with_flag() (from cmdpool/core) for details.
#
cmdpool_manage_iter_slots_with_flag() {
   local F_CMDPOOL_ITER_ON_ERROR=true
   local flag="${1:?}"
   shift
   if cmdpool_manage_want_all_slots; then
      cmdpool_iter_slots_with_flag "${flag}" "${CMDPOOL_ROOT}" "" "$@"
   else
      cmdpool_iter_slots_with_flag "${flag}" "${CMDPOOL_ROOT}" "" \
         cmdpool_manage_call_if_slotmatch "$@"
   fi
}
