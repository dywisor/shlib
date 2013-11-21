#@section functions

# @private @noreturn die__extended (
#    message=, code=2, **DIE=exit, **F_ON_DIE=, **PRINT_FUNCTRACE=n
# )
#
#  if %F_ON_DIE has is not defined / has a null value:
#   Prints %message to stderr and calls %DIE(code) afterwards.
#   Also prints the function trace if it is available (bash) and
#   PRINT_FUNCTRACE is set to 'y'
#  else:
#   Calls %F_ON_DIE ( message, code ). Does the actions above
#   only if %F_ON_DIE() returns a non-zero value.
#
die__extended() {
   [ "${HAVE_BREAKPOINT_SUPPORT:-n}" != "y" ] || breakpoint die

   if [ -z "${F_ON_DIE:-}" ] || ! ${F_ON_DIE} "${1}" "${2}"; then
      if [ -n "${1}" ]; then
         eerror "${1}" "died:"
      else
         eerror "" "died."
      fi
      if [ "${PRINT_FUNCTRACE:-n}" = "y" ] && [ -n "${FUNCNAME-}" ]; then
         print_functrace eerror
      fi
      ${DIE:-exit} ${2:-2}
   fi
   return 0
}

#@section funcvars
# make die__extended() available
__F_DIE=die__extended
