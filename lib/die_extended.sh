if [ -z "${__HAVE_SHLIB_DIE__:-}" ]; then
readonly __HAVE_SHLIB_DIE__=y

# @private @noreturn die__extended (
#    message=, code=2, **DIE=exit, **F_ON_DIE=, **PRINT_FUNCTRACE=y
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

# make die__extended() available
__F_DIE=die__extended

# @private void die__autodie ( *argv )
#
#  Runs *argv. Dies on non-zero return code.
#
die__autodie() {
   if "$@"; then
      return 0
   else
      die "command '$*' returned $?."
   fi
}

# void autodie ( *argv, **AUTODIE=die__autodie )
#
#  Runs AUTODIE ( *argv ) which is supposed to let the script die on
#  non-zero return code.
#
autodie() { ${AUTODIE:-die__autodie} "$@"; }

# @function_alias run() copies autodie()
#
run() { ${AUTODIE:-die__autodie} "$@"; }

fi
