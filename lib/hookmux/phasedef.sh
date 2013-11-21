#@section module_vars

# @private list __PHASEDEF_PHASES
#
#  whitespace-separated list containing all known phases
#
__PHASEDEF_PHASES=

# @private list __PHASEDEF_VIRTUAL_PHASES
#
#  whitespace-seperated list of so-called "virtual" phases
#  (e.g. phases representing common actions like dependency checks)
#
#  It's not necessary to add virtual phases to __PHASEDEF_VIRTUAL_PHASES,
#  but doing so allows to automatically create/unset default functions in
#  phasedef_set_default_phase_functions()/phasedef_unset_phase_functions().
#
__PHASEDEF_VIRTUAL_PHASES=

# @private str __IN_HOOK_PHASE__
#
#  name of the phase currently being executed or empty (=no phase)
#
__IN_HOOK_PHASE__=


#@section vars

# str PHASEDEF_PHASEFUNC_PREFIX
#
#  Prefix for phase function names.
#  Should end with an underscore char '_' (if not empty).
#
PHASEDEF_PHASEFUNC_PREFIX=


#@section funcdef

# @funcdef <return type> @nophase <function name> (
#    *args, **kwargs, **__IN_HOOK_PHASE__
# )
#
#  A function that must not be called while executing a phase.
#

# @funcdef <return type> @phaseonly <function name> (
#    *args, **kwargs, **__IN_HOOK_PHASE__
# )
#
#  A function that is only allowed to be called while executing a phase.
#


#@section functions

# int phasedef_in_phase ( **__IN_HOOK_PHASE__ )
#
phasedef_in_phase() {
   [ -z "${__IN_HOOK_PHASE__-}" ]
}

# void phasedef_deny_if_in_phase ( func_name="UNDEF" )
#
phasedef_deny_if_in_phase() {
   if [ -n "${__IN_HOOK_PHASE__-}" ]; then
      function_die \
         "${1:-UNDEF} not allowed while executing phase ${__IN_HOOK_PHASE__}" \
         phasedef_deny_if_in_phase
   fi
}

# void phasedef_deny_if_not_in_phase ( func_name="UNDEF" )
#
phasedef_deny_if_not_in_phase() {
   if [ -z "${__IN_HOOK_PHASE__-}" ]; then
      function_die \
         "${1:-UNDEF} only allowed while executing a phase" \
         phasedef_deny_if_not_in_phase
   fi
}

# @nophase void phasedef_register ( *phase, **__PHASEDEF_PHASES! )
#
#  Adds a phase to the list of known phases.
#
phasedef_register() {
   phasedef_deny_if_in_phase phasedef_register
   if [ -n "$*" ]; then
      __PHASEDEF_PHASES="${__PHASEDEF_PHASES-}${__PHASEDEF_PHASES:+ }${*}"
   fi
}

# @nophase void phasedef_register_virtual (
#    *vphase, **__PHASEDEF_VIRTUAL_PHASES!
# )
#
#  Adds a phase to the list of virtual phases.
#
phasedef_register_virtual() {
   phasedef_deny_if_in_phase phasedef_register_virtual
   if [ -n "$*" ]; then
      if [ -z "${__PHASEDEF_VIRTUAL_PHASES-}" ]; then
         __PHASEDEF_VIRTUAL_PHASES="$*"
      else
         __PHASEDEF_VIRTUAL_PHASES="${__PHASEDEF_VIRTUAL_PHASES} ${*}"
      fi
   fi
}

# int phasedef_is_phase ( name:=**PHASE, **__PHASEDEF_PHASES )
#
#  Returns 0 if %name is a phase, else 1.
#
phasedef_is_phase() { list_has "${1:-${PHASE:?}}" ${__PHASEDEF_PHASES}; }

# @nophase void phasedef_enter_phase ( phase=**PHASE, **__IN_HOOK_PHASE__! )
#
#  Sets %__IN_HOOK_PHASE__. It is not checked whether %phase is a valid phase.
#
phasedef_enter_phase() {
   local phase="${1:-${PHASE:?}}"
   phasedef_deny_if_in_phase phasedef_enter_phase
   __IN_HOOK_PHASE__="${phase}" || \
      function_die "cannot enter phase '${phase}'" phasedef_enter_phase
   #   ^ readonly
}

# @phaseonly void phasedef_freeze_phase (
#    **__IN_HOOK_PHASE__+r,
#    **__PHASEDEF_PHASES+r, **__PHASEDEF_VIRTUAL_PHASES+r
# )
#
#  Makes %__IN_HOOK_PHASE__, **__PHASEDEF_PHASES and
#  **__PHASEDEF_VIRTUAL_PHASES readonly,
#  which means that the current phase cannot be left and the list of
#  known phases can no longer be modified.
#
#  Useful for subshells etc.
#
phasedef_freeze_phase() {
   phasedef_deny_if_not_in_phase phasedef_freeze_phase
   readonly __IN_HOOK_PHASE__
   readonly __PHASEDEF_PHASES
   readonly __PHASEDEF_VIRTUAL_PHASES
   return 0
}

# @phaseonly void phasedef_leave_phase ( **__IN_HOOK_PHASE__! )
#
#  Sets %__IN_HOOK_PHASE__ to "no phase" (empty str).
#
phasedef_leave_phase() {
   phasedef_deny_if_not_in_phase phasedef_leave_phase
   __IN_HOOK_PHASE__= || \
      function_die \
         "cannot leave phase ${__IN_HOOK_PHASE__}: frozen" \
         phasedef_leave_phase
}

# @phaseonly void phasedef_unset_phase_functions ( **__PHASEDEF_PHASES )
#
#  Unsets all phase functions.
#
phasedef_unset_phase_functions() {
   phasedef_deny_if_not_in_phase phasedef_unset_phase_functions
   unset -f ${__PHASEDEF_PHASES?} ${__PHASEDEF_VIRTUAL_PHASES?} || true
}

# @phaseonly void phasedef_set_default_phase_functions (
#    override="y", **__PHASEDEF_PHASES
# )
#
phasedef_set_default_phase_functions() {
   phasedef_deny_if_not_in_phase phasedef_set_default_phase_functions
   if [ "${1:-y}" = "y" ]; then
      eval_nullfunc ${__PHASEDEF_PHASES?} ${__PHASEDEF_VIRTUAL_PHASES?}
   else
      local f
      for f in ${__PHASEDEF_PHASES} ${__PHASEDEF_VIRTUAL_PHASES?}; do
         function_defined "${f}" || eval_nullfunc "${f}"
      done
   fi
   return 0
}

# int phasedef_get_phase_function (
#    phase:=**__IN_HOOK_PHASE__:=**PHASE,
#    **PHASEDEF_PHASEFUNC_PREFIX,
#    **v0!
# )
#
#  Sets to %v0 to the name of the requested phase function.
#  Returns 0 if this function is defined, else 1.
#
phasedef_get_phase_function() {
   local phase="${1:-${__IN_HOOK_PHASE__:-${PHASE:?}}}"
   v0="${PHASEDEF_PHASEFUNC_PREFIX-}${phase}"
   function_defined "${v0}"
}
