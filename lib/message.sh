# void {einfo,ewarn,eerror}{,n}_nocolor ( message, header=<INFO,WARN,ERROR> )
#
#  Prints ${header}${message} to stdout.
#
einfo_nocolor()   { printf -- "${2:-[INFO]}${1:+ }${1-}\n"; }
ewarn_nocolor()   { printf -- "${2:-[WARN]}${1:+ }${1-}\n"; }
eerror_nocolor()  { printf -- "${2:-[ERROR]}${1:+ }${1-}\n"; }

einfon_nocolor()   { printf -- "${2:-[INFO]}${1:+ }${1-}"; }
ewarnn_nocolor()   { printf -- "${2:-[WARN]}${1:+ }${1-}"; }
eerrorn_nocolor()  { printf -- "${2:-[ERROR]}${1:+ }${1-}"; }

# void __message_colored ( text_colored, color, text_nocolor )
#
#  Prints <text_colored><text_nocolor> using the specified color.
#
__message_colored() {
   printf -- "\033[${2:?}${1:?}\033[0m${3:+ }${3-}\n"
}

# void __messagen_colored ( text_colored, color, text_nocolor ):
#
#  Like __message_colored(), but doesn't append a trailing newline.
#
__messagen_colored() {
   printf -- "\033[${2:?}${1:?}\033[0m${3:+ }${3-}"
}


# void {einfo,ewarn,eerror}{,n}_color ( message, header=<*|INFO,WARN,ERROR> )
#
# Prints ${header}${message} to stdout (colored output).
#

##einfo_color()  { __message_colored "${2:-[INFO]}"  '1;32m' "${1-}"; }
##ewarn_color()  { __message_colored "${2:-[WARN]}"  '1;33m' "${1-}"; }
##eerror_color() { __message_colored "${2:-[ERROR]}" '1;31m' "${1-}"; }

einfo_color()  { __message_colored "${2:-*}" '1;32m' "${1-}"; }
ewarn_color()  { __message_colored "${2:-*}" '1;33m' "${1-}"; }
eerror_color() { __message_colored "${2:-*}" '1;31m' "${1-}"; }

einfon_color()  { __messagen_colored "${2:-*}" '1;32m' "${1-}"; }
ewarnn_color()  { __messagen_colored "${2:-*}" '1;33m' "${1-}"; }
eerrorn_color() { __messagen_colored "${2:-*}" '1;31m' "${1-}"; }

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

      einfon()   { einfon_color  "$@"; }
      ewarnn()   { ewarnn_color  "$@" 1>&2; }
      eerrorn()  { eerrorn_color "$@" 1>&2; }
      messagen() { __messagen_colored "$*" '1;29m'; }

   else

      einfo()    { einfo_nocolor  "$@"; }
      ewarn()    { ewarn_nocolor  "$@" 1>&2; }
      eerror()   { eerror_nocolor "$@" 1>&2; }
      message()  { printf -- "${*}\n"; }

      einfon()   { einfon_nocolor  "$@"; }
      ewarnn()   { ewarnn_nocolor  "$@" 1>&2; }
      eerrorn()  { eerrorn_nocolor "$@" 1>&2; }
      messagen() { printf -- "${*}"; }

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
   if __verbose__ || __debug__; then
      einfo "$@"
   fi
   return 0
}

# void veinfon ( message, header, **DEBUG= )
#
#  Like veinfo(), but doesn't append a trailing newline.
#
veinfon() {
   if __verbose__ || __debug__; then
      einfon "$@"
   fi
   return 0
}

# void printvar ( *varname, **F_PRINTVAR=einfo, **PRINTVAR_SKIP_EMPTY=n )
#
#  Prints zero or variables (specified by name) by calling
#  F_PRINTVAR ( "<name>=<value> ) for each variable/value pair.
#
#
printvar() {
   local val
   while [ $# -gt 0 ]; do
      eval val="\${${1}-}"
      if [ -n "${val}" ] || [ "${PRINTVAR_SKIP_EMPTY:-n}" != "y" ]; then
         ${F_PRINTVAR:-einfo} "${1}=\"${val}\""
      fi
      shift
   done
}

[ "${MESSAGE_BIND_FUNCTIONS:-y}" != "y" ] || message_bind_functions
