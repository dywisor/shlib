#@section functions

# void die_get_msg_and_header  (
#    message, **DIE_WORD:="died", **msg!, **header!
# )
#
#  Sets %msg and %header.
#
die_get_msg_and_header() {
   if [ -n "${1-}" ]; then
      msg=" ${1}"
      header="${DIE_WORD:-died}:"
   else
      msg=
      header="${DIE_WORD:-died}."
   fi
}

# @private @noreturn die__minimal ( message, code, **DIE=exit )
#
#  Prints %message to stderr and calls %DIE(code) afterwards.
#
die__minimal() {
   [ "${HAVE_BREAKPOINT_SUPPORT:-n}" != "y" ] || breakpoint die

   local msg header
   die_get_msg_and_header "${1-}"

   if [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
      eerror "${msg# }" "${header}"
   else
      echo "${header}${msg}" 1>&2
   fi
   ${DIE:-exit} ${2:-2}
}

# @noreturn die ( message=, code=2, **__F_DIE=die__minimal )
#
#  Calls __F_DIE ( message, code ).
#
die() {
   local __MESSAGE_INDENT=
   ${__F_DIE:-die__minimal} "${1-}" "${2:-2}"
}

#@section funcvars
: ${HAVE_DIE:=y}
