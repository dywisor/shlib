if [ -z "${__HAVE_SHLIB_DIE__:-}" ]; then
readonly __HAVE_SHLIB_DIE__=y

# @noreturn die ( message=, code=2, **DIE=exit, **F_ON_DIE= )
#
#  if %F_ON_DIE has is not defined / has a null value:
#   Prints %message to stderr and calls %DIE(code) afterwards.
#  else:
#   Calls %F_ON_DIE ( message, code ). Does the actions above
#   only if %F_ON_DIE() returns a non-zero value.
#
die() {
   set -- "${1:-}" "${2:-2}"

   if [ -z "${F_ON_DIE:-}" ] || ! ${F_ON_DIE} "${1}" "${2}"; then
      if [ -n "${1}" ]; then
         eerror "${1}" "died:"
      else
         eerror "" "died."
      fi
      ${DIE:-exit} ${2:-2}
   fi
   return 0
}

# @private @noreturn die__function ( function_name, message=, code=3 )
#
#  Common functionality for function_die().
#  Calls die( function_name~message, code ).
#
die__function() {
   if [ -n "${2:-}" ]; then
      die "while execution function ${1%()}(): ${2}" ${3:-3}
   else
      die "while execution function ${1%()}()." ${3:-3}
   fi
}

# void autodie ( *argv )
#
#  Runs *argv. Dies on non-zero return code.
#
autodie() {
   if "$@"; then
      return 0
   else
      die "command '$*' returned $?."
   fi
}

fi
