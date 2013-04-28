# @private @noreturn die__minimal ( message, code )
#
#  Prints %message to stderr and calls exit(code) afterwards.
#
die__minimal() {
   [ "${HAVE_BREAKPOINT_SUPPORT:-n}" != "y" ] || breakpoint die

   if [ "${__HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
      eerror "${1}" "died:"
   elif [ -n "${1}" ]; then
      echo "died: ${1}" 1>&2
   else
      echo "died." 1>&2
   fi
   exit "${2}"
}

# @noreturn die ( message=, code=2, **__F_DIE=die__minimal )
#
#  Calls __F_DIE ( message, code ).
#
die() {
   ${__F_DIE:-die__minimal} "${1-}" "${2:-2}"
}
