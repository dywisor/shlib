#@section functions

# int breakpoint (
#    breakpoint_name, *breakpoint_name_alias,
#    **BREAKPOINTS_ALL=n, **BREAKPOINTS=,
#    **F_BREAKPOINT=<start a shell>
# )
#
#  This function implements interactive breakpoints.
#  Adding a breakpoint to your code is as simple as putting
#    breakpoint <NAME> [<alternate names>]
#  wherever you want one (plus including this module).
#
#  Then, it is checked whether the breakpoint or any of the alternate names
#  are enabled, by probing these variables:
#
#  * BREAKPOINTS_ALL
#     This variable, if set to 'y', enables all breakpoints,
#     regardless of their name.
#  * BREAKPOINTS
#     This is a list of breakpoints.
#     The breakpoint is enabled if it appears in this variable.
#
#  The function starts shell or calls F_BREAKPOINT (<breakpoint>) (if set)
#  if the breakpoint is enabled, else it does nothing.
#  The launched shell has to return a non-zero value, else the script dies.
#
#  Finally, the previous return code (prior to calling this function) is
#  returned.
#
#  IOW:
#   This function does nothing and passes the last return code if the
#   breakpoint is disabled.
#
#  A typical use case would be
#     <do sth. critical> || breakpoint <critical_section_failed>
#
#  You definitely want to pass your own F_BREAKPOINT function if runtime
#  inspection and/or manipulation is desired.
#
#  F_BREAKPOINT can also be used to edit the last_rc variable, which
#  stores the return code of the command prior to calling this function.
#
breakpoint() {
   local last_rc=${?} breakpoint
   : ${1:?}

   if [ "${BREAKPOINTS_ALL:-n}" = "y" ]; then

      breakpoint="${1}"

   elif [ -n "${BREAKPOINTS-}" ]; then

      # breakpoint enabled?
      for bp; do
         if list_has "${bp}" ${BREAKPOINTS-}; then
            breakpoint="${1}"
            break
         fi
      done

   fi

   if [ -z "${breakpoint-}" ]; then
      ${LOGGER} --level=DEBUG --facility=breakpoint "${1} (not enabled)"

   elif [ -n "${F_BREAKPOINT-}" ]; then
      ${LOGGER} -0 --level=DEBUG --facility=breakpoint "${breakpoint}"

      ${F_BREAKPOINT} "${breakpoint}"

   else
      ${LOGGER} -0 --level=DEBUG --facility=breakpoint "${breakpoint}"

      message "\n*** BREAKPOINT '${breakpoint}' ***\n"
      if [ ${last_rc} -ne 0 ]; then
         eerror "last return code was ${last_rc}\n"
      else
         einfo "last return code was 0\n"
      fi
      einfo "Starting a shell (${SHELL:-/bin/sh}) ..."
      einfo "The script will die if this shell exits with a non-zero code\n"

      ${SHELL:-/bin/sh} || breakpoint__die "shell returned ${?}."
   fi

   return ${last_rc}
}

# @private @noreturn breakpoint__die (...)
#
#  private die() wrapper function.
#
breakpoint__die() {
   local BREAKPOINTS_ALL=n BREAKPOINTS=""
   set -- "${1-}" "${2:-${last_rc:?}}"
   if [ -n "${1}" ]; then
      die "${1}" "${2}"
   else
      die "at breakpoint ${breakpoint:-?} (last retcode = ${2})." "${2}"
   fi
}

# void critical_breakpoint ( <see breakpoint()> )
#
#  Calls breakpoint ( ..., "critical" ) and dies on non-zero return.
#
critical_breakpoint() {
   breakpoint "$@" "critical" || \
      breakpoint__die "at critical breakpoint ${1-} (rc=$?)" ${?}
}


#@section module_features
HAVE_BREAKPOINT_SUPPORT=y
