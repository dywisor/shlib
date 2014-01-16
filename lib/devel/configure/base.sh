#@section functions

### message functions

# void configure_{echo,info,warn,error}{,n} ( message, ... )
#
#  Prints a normal/info/warning/error message (with/without a trailing newline
#  char). The info, warn and error functions accepts additional args.
#
configure_echo()   { echo    "$@"; }
configure_info()   { einfo   "$@"; }
configure_warn()   { ewarn   "$@"; }
configure_error()  { eerror  "$@"; }
configure_echon()  { echo -n "$@"; }
configure_infon()  { einfon  "$@"; }
configure_warnn()  { ewarnn  "$@"; }
configure_errorn() { eerrorn "$@"; }

# void configure_check_message_begin ( message, message_header=<default> )
#
#  Prints a "Checking whether <message> ... " info message, optionally
#  with the given header (instead of the default one).
#
#  Does not append a trailing newline char.
#
configure_check_message_begin() {
   configure_infon "Checking whether ${1} ... " ${2-}
}

# void configure_check_message_end ( message )
#
#  Completes a "checking whether ..." message (including a trailing newline
#  char).
#
configure_check_message_end() {
   configure_echo "${1}"
}

# @function_alias configure_die() is die()
#
#  configure-related modules / script should call this script instead of die().
#
configure_die() { die "$@"; }


# int configure_which_nonfatal ( prog_name, **v0! )
#
#  Returns 0 if program with the given name could be found, else 1.
#  Stores the path to the program in %v0.
#
configure_which_nonfatal() {
   v0=
   [ $# -eq 1 ] && [ -n "${1-}" ] || \
      configure_die "configure_which: bad usage."

   configure_check_message_begin "${1} exists"
   if qwhich_single "${1}"; then
      configure_check_message_end "${v0}"
   else
      configure_check_message_end "no"
      return 1
   fi
}

# int configure_which ( *prog_names, [**v0!] ), raises configure_die()
#
#  Calls configure_which_nonfatal() for each prog_name and dies on first
#  failure.
#
#  Leaks %v0 iff exactly one arg is given.
#
configure_which() {
   if [ $# -eq 1 ]; then
      configure_which_nonfatal "${1}" || configure_die
   else
      local v0
      while [ $# -gt 0 ]; do
         [ -z "${1-}" ] || configure_which_nonfatal "${1}" || configure_die
         shift
      done
   fi
}

# void configure_which_which(), raises configure_die()
#
#  Verifies that "which" can be found.
#
configure_which_which() {
   if configure_which_nonfatal which; then
      return 0
   else
      configure_die \
         "${SCRIPT_NAME} cannot detect whether programs are available."
   fi
}
