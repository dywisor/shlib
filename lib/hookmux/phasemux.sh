# @extern funcref LOGGER

# @extern @noreturn die ( message, code, **DIE=exit )
#
#  Prints %message to stderr and calls %DIE(code) afterwards.
#

# @extern void OVERRIDE_FUNCTION ( function_name ), raises die()
#
#  Helper function for @override.
#  Dies if %function_name is not defined and unsets the function otherwise.
#
#  Has to be called _before_ redefining the function.
#

# @extern void phasedef_deny_if_in_phase ( func_name="UNDEF" )
#

# @extern void phasedef_deny_if_not_in_phase ( func_name="UNDEF" )
#

# @extern @nophase void phasedef_register ( *phase, **__PHASEDEF_PHASES! )
#
#  Adds a phase to the list of known phases.
#

# @extern @nophase void phasedef_register_virtual (
#    *vphase, **__PHASEDEF_VIRTUAL_PHASES!
# )
#
#  Adds a phase to the list of virtual phases.
#

# str PHASEMUX_FALLBACK_PHASE
#
#  phase that is executed if a hook script doesn't implement the
#  specific phase.
#  Can be set to the empty str, which disables the fallback behavior.
#
: ${PHASEMUX_FALLBACK_PHASE="any_phase"}

# @can-override int phasemux_enter()
#
#  Function that is called prior to loading the hook file,
#  after setting up essential variables.
#
#  Usage examples:
#  * provide default values for variables
#
#  Does nothing.
#
phasemux_enter() {
   return 0
}

# @can-override int phasemux_leave()
#
#  Function that is called just before leaving the phase.
#
#  Does nothing.
#
phasemux_leave() {
   return 0
}

# @can-override int phasemux_hook_loaded()
#
#  Function that is called right after succesfully loading
#  the hook script file.
#
#  Usage examples:
#  * verify variables
#
#  Does nothing.
#
phasemux_hook_loaded() {
   return 0
}

# @can-override int phasemux_hook_prepare()
#
#  Function that is called just before calling the phase function.
#
#  Usage examples:
#  * change directory
#
#  Does nothing.
#
phasemux_hook_prepare() {
   return 0
}

# @can-override int phasemux_hook_done()
#
#  Function that is called if the phase function succeeded.
#
#  Does nothing.
#
phasemux_hook_done() {
   return 0
}

# ~int phasemux_run_phase_function ( func, *args, **LOGGER )
#
#  Calls a phase function and logs what happens.
#  Returns the phase functions return value.
#
phasemux_run_phase_function() {
   : ${1:?}
   local v0=

   ${LOGGER} --level=DEBUG "executing phase function '${1}'"
   local rc=0
   "$@" || rc=${?}
   if [ ${rc} -eq 0 ]; then
      ${LOGGER} --level=DEBUG "phase function succeeded"
   else
      ${LOGGER} --level=ERROR \
         "phase function ${1}() returned non-zero (${rc})"
   fi
   return ${rc}
}

# ~int phasemux_run_virtual_phase_function (
#    func, *args, **PHASE_RESTRICT, **PHASE, **LOGGER
# )
#
phasemux_run_virtual_phase_function() {
   : ${1:?}
   local v0=
   if \
      [ "${PHASE}" != "${1}" ] && \
      ! list_has "${1}" ${PHASE_RESTRICT-} && \
      phasedef_get_phase_function "${1}"
   then
      shift
      phasemux_run_phase_function "${v0}" "$@"
   else
      return 0
   fi
}

# ~int phasemux_call_function ( func, *args, **LOGGER )
#
#  Calls a function and logs what happens.
#  Returns the functions return value.
#
phasemux_call_function() {
   : ${1:?}
   local v0=

   ${LOGGER} --level=DEBUG "calling function '${1}'"
   local rc=0
   "$@" || rc=${?}
   if [ ${rc} -ne 0 ]; then
      ${LOGGER} --level=ERROR \
         "function ${1}() returned non-zero (${rc})"
   fi
   return ${rc}
}


# int phasemux_run_hook_script ( file, **PHASE )
#
#  Loads a hook script and executes %PHASE in a subshell.
#
phasemux_run_hook_script() {
   : ${1:?} ${PHASE:?}

   (
      readonly LOGGER
      readonly PHASE
      readonly PHASEDEF_PHASEFUNC_PREFIX
      readonly HOOK_FILE="${1}"
      v0="${HOOK_FILE##*/}"
      readonly HOOK_NAME="${v0%.*}"

      ${LOGGER} --level=DEBUG "running hook '${HOOK_NAME}'"

      set --

      phasedef_register_virtual depend common_init
      phasemux_call_function phasedef_enter_phase  || return 1
      phasemux_call_function phasedef_freeze_phase || return 2
      phasedef_unset_phase_functions

      v0=
      PHASE_RESTRICT=
      phasemux_call_function phasemux_enter || return 3

      if ! . "${HOOK_FILE}"; then
         ${LOGGER} --level=ERROR \
            "failed to load hook file '${HOOK_FILE}'"
         return 4
      fi

      phasemux_call_function phasemux_hook_loaded || return 5

      readonly PHASE_RESTRICT
      PHASEFUNC= || die

      MSG_NOEX="not exeuting phase for '${HOOK_NAME}'"

      if list_has "${PHASE}" ${PHASE_RESTRICT}; then
         ${LOGGER} --level=DEBUG "${MSG_NOEX} (PHASE_RESTRICT)"

      elif phasedef_get_phase_function; then
         PHASEFUNC="${v0}"

      elif \
         [ -z "${PHASEMUX_FALLBACK_PHASE-}" ] || \
         [ "${PHASEMUX_FALLBACK_PHASE}" = "${PHASE}" ]
      then
         ${LOGGER} --level=DEBUG "${MSG_NOEX}: no phase function defined"

      elif list_has "${PHASEMUX_FALLBACK_PHASE}" ${PHASE_RESTRICT}; then
         ${LOGGER} --level=DEBUG "${MSG_NOEX}: fallback in PHASE_RESTRICT"

      elif phasedef_get_phase_function "${PHASEMUX_FALLBACK_PHASE}"; then
         PHASEFUNC="${v0}"

      else
         ${LOGGER} --level=DEBUG \
            "${MSG_NOEX}: no phase/fallback function(s) defined"
      fi

      unset -v MSG_NOEX
      readonly PHASEFUNC

      if [ -n "${PHASEFUNC}" ]; then
         phasemux_call_function phasemux_hook_prepare    || return 20

         # retcodes 21..29: pre-phase virtual phases
         phasemux_run_virtual_phase_function depend      || return 21
         phasemux_run_virtual_phase_function common_init || return 22

         phasemux_run_phase_function "${PHASEFUNC}"      || return 30

         # retcodes 31..39: post-phase virtual phases

         phasemux_call_function phasemux_hook_done       || return 40
      fi

      phasemux_leave || return 50
   )
}

# int phasemux_run_hook_dir (
#    phase, dirpath, **PHASEMUX_CONTINUE_ON_ERROR=y
# ), raises function_die()
#
#  Calls phasemux_run_hook_script() with the given phase for each
#  hook script in %dirpath.
#
phasemux_run_hook_dir() {
   : ${LOGGER:?}
   if [ -z "${1-}" ] || [ -z "${2-}" ]; then
      function_die "bad usage" phasemux_run_hook_dir
   fi

   local PHASE="${1}" HOOKDIR="${2}"
   local hook_count=0

   if ! phasedef_is_phase; then
      ${LOGGER} --level=ERROR "invalid phase '${PHASE}'"
      return 1

   elif [ ! -d "${HOOKDIR}" ]; then
      ${LOGGER} --level=WARN "hook dir '${HOOKDIR}' does not exist."
      return 2

   else
      local hook_file
      for hook_file in "${HOOKDIR}/"*".sh"; do
         # ^ COULDFIX: hardcoded file ext

         if [ -f "${hook_file}" ]; then
            if phasemux_run_hook_script "${hook_file}"; then
               hook_count=$(( ${hook_count} + 1 ))
            else
               ${LOGGER} --level=ERROR \
                  "errors occured while running hook script '${hook_file}' (${?})"

               if [ "${PHASEMUX_CONTINUE_ON_ERROR:-y}" = "y" ]; then
                  return 30
               fi
            fi
         fi
      done

      if [ ${hook_count} -eq 0 ]; then
         ${LOGGER} --level=INFO "${HOOKDIR}: no hooks found"
      else
         ${LOGGER} --level=DEBUG "${HOOKDIR}: ${hook_count} hook(s) succeeded"
      fi

      return 0
   fi
}
