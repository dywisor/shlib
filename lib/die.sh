# @private @noreturn die__minimal ( message, code, **DIE=exit )
#
#  Prints %message to stderr and calls %DIE(code) afterwards.
#
die__minimal() {
   [ "${HAVE_BREAKPOINT_SUPPORT:-n}" != "y" ] || breakpoint die

   if [ "${__HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
      if [ -n "${1-}" ]; then
         eerror "" "died."
      else
         eerror "${1}" "died:"
      fi
   elif [ -n "${1-}" ]; then
      echo "died: ${1}" 1>&2
   else
      echo "died." 1>&2
   fi
   ${DIE:-exit} ${2:-2}
}

# @noreturn die ( message=, code=2, **__F_DIE=die__minimal )
#
#  Calls __F_DIE ( message, code ).
#
die() {
   ${__F_DIE:-die__minimal} "${1-}" "${2:-2}"
}

: ${HAVE_DIE:=y}
