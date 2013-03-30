# void {einfo,ewarn,eerror}_nocolor ( message, header=<INFO,WARN,ERROR> )
#
#  Prints ${header}${message} to stdout.
#
einfo_nocolor()   { printf "${2:-[INFO]}${1:+ }${1-}\n"; }
ewarn_nocolor()   { printf "${2:-[WARN]}${1:+ }${1-}\n"; }
eerror_nocolor()  { printf "${2:-[ERROR]}${1:+ }${1-}\n"; }

# void __message_colored ( text_colored, color, text_nocolor )
#
#  Prints <text_colored><text_nocolor> using the specified color.
#
__message_colored() {
   printf "\033[${2:?}${1:?}\033[0m${3:+ }${3-}\n"
}

# void {einfo,ewarn,eerror}_color ( message, header=<*|INFO,WARN,ERROR> )
#
# Prints ${header}${message} to stdout (colored output).
#

#einfo_color()  { __message_colored "${2:-[INFO]}"  '1;32m' "${1-}"; }
#ewarn_color()  { __message_colored "${2:-[WARN]}"  '1;33m' "${1-}"; }
#eerror_color() { __message_colored "${2:-[ERROR]}" '1;31m' "${1-}"; }

einfo_color()  { __message_colored "${2:-*}" '1;32m' "${1-}"; }
ewarn_color()  { __message_colored "${2:-*}" '1;33m' "${1-}"; }
eerror_color() { __message_colored "${2:-*}" '1;31m' "${1-}"; }

# void message_bind_functions ( **NO_COLOR=n )
#
#  Binds the einfo, ewarn, eerror and message functions according to the
#  current setting of NO_COLOR.
#  ewarn() and eerror() will output to stderr.
#  Also affects veinfo() and printvar(), which depend on einfo().
#
message_bind_functions() {
   HAVE_MESSAGE_FUNCTIONS=n
   __HAVE_MESSAGE_FUNCTIONS=n
   unset -f einfo ewarn eerror edebug message

   if [ "${NO_COLOR:-n}" != "y" ]; then

      einfo()   { einfo_color  "$@"; }
      ewarn()   { ewarn_color  "$@" 1>&2; }
      eerror()  { eerror_color "$@" 1>&2; }
      message() { __message_colored "$*" '1;29m'; }

   else

      einfo()   { einfo_nocolor  "$@"; }
      ewarn()   { ewarn_nocolor  "$@" 1>&2; }
      eerror()  { eerror_nocolor "$@" 1>&2; }
      message() { printf "${*}\n"; }

   fi
   __HAVE_MESSAGE_FUNCTIONS=y
   HAVE_MESSAGE_FUNCTIONS=y
}

# void veinfo ( message, header, **DEBUG=n )
#
#  Prints the given message/header with einfo() if DEBUG is set to 'y',
#  else does nothing.
#
veinfo() {
   [ "${DEBUG:-n}" != "y" ] || einfo "${1-}" "${2:-[DEBUG]}"
}

# void printvar ( *varname, **F_PRINTVAR=einfo )
#
#  Prints zero or variables (specified by name) by calling
#  F_PRINTVAR ( "<name>=<value> ) for each variable/value pair.
#
#
printvar() {
   local val
   while [ $# -gt 0 ]; do
      eval val="\${${1}-}"
      ${F_PRINTVAR:-einfo} "${1}=\"${val}\""
      shift
   done
}

[ "${MESSAGE_BIND_FUNCTIONS:-y}" != "y" ] || message_bind_functions
