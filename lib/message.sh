#@section const
MESSAGE_COLOR_GREEN="1;32m"
MESSAGE_COLOR_YELLOW="1;33m"
MESSAGE_COLOR_RED="1;31m"
MESSAGE_COLOR_WHITE="1;29m"

#@section funcdef

# @funcdef message_emitter[<type>] <function name> (
#    header=<default>, text=, text_append=,
#    color=, header_nocolor, header_colored,
#    **__MESSAGE_INDENT=
# )
#
#  Prints a message to stdout/stderr/file/...
#

#@section functions

# @stdout @message_emitter<colored> __message_colored (
#    header=<default>, text=, text_append=,
#    color=, header_nocolor, header_colored,
#    **__MESSAGE_INDENT=
# )
#
__message_colored() {
   printf -- "${__MESSAGE_INDENT-}\033[${4:?}%s\033[0m%s${3-}" \
      "${1:-${6?}}" "${2:+ }${2-}"
}

# @stdout @message_emiter<nocolor> __message_nocolor (
#    header=<default>, text=, text_append=,
#    color=, header_nocolor, header_colored,
#    **__MESSAGE_INDENT=
# )
#
__message_nocolor() {
   printf -- "${__MESSAGE_INDENT-}%s%s${3-}" \
      "${1:-${5?}}" "${2:+ }${2-}"
}


## actual message functions

# @stdout void einfo (
#    message, header="INFO"|"*",
#    **MESSAGE_COLOR_INFO=<default>, **__F_MESSAGE_EMITTER
# )
#
einfo() {
   ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_INFO:-${MESSAGE_COLOR_GREEN}}" '[INFO]' '*'
}

# @stdout void einfon (
#    message, header="INFO"|"*",
#    **MESSAGE_COLOR_INFO=<default>, **__F_MESSAGE_EMITTER
# )
#
einfon() {
   ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '' \
      "${MESSAGE_COLOR_INFO:-${MESSAGE_COLOR_GREEN}}" '[INFO]' '*'
}

# @stderr void ewarn (
#    message, header="WARN"|"*",
#    **MESSAGE_COLOR_WARN=<default>, **__F_MESSAGE_EMITTER
# )
#
ewarn() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_WARN:-${MESSAGE_COLOR_YELLOW}}" '[WARN]' '*'
}

# @stderr void ewarnn (
#    message, header="WARN"|"*",
#    **MESSAGE_COLOR_WARN=<default>, **__F_MESSAGE_EMITTER
# )
#
ewarnn() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '' \
      "${MESSAGE_COLOR_WARN:-${MESSAGE_COLOR_YELLOW}}" '[WARN]' '*'
}

# @stderr void eerror (
#    message, header="ERROR"|"*",
#    **MESSAGE_COLOR_ERROR=<default>, **__F_MESSAGE_EMITTER
# )
#
eerror() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_ERROR:-${MESSAGE_COLOR_RED}}" '[ERROR]' '*'
}

# @stderr void eerrorn (
#    message, header="ERROR"|"*",
#    **MESSAGE_COLOR_ERROR=<default>, **__F_MESSAGE_EMITTER
# )
#
eerrorn() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_ERROR:-${MESSAGE_COLOR_RED}}" '[ERROR]' '*'
}

# @stdout void message ( text, **__F_MESSAGE_EMITTER )
#
message() {
   ${__F_MESSAGE_EMITTER:?} "${1-}" "" '\n' "${MESSAGE_COLOR_WHITE}" "" ""
}

# @stdout void messagen ( text, **__F_MESSAGE_EMITTER )
#
messagen() {
   ${__F_MESSAGE_EMITTER:?} "${1-}" "" '' "${MESSAGE_COLOR_WHITE}" "" ""
}


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

   if [ "${NO_COLOR:-n}" != "y" ]; then
      __F_MESSAGE_EMITTER="__message_colored"
      HAVE_COLORED_MESSAGE_FUNCTIONS=y
   else
      __F_MESSAGE_EMITTER="__message_nocolor"
      HAVE_COLORED_MESSAGE_FUNCTIONS=n
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

# void veinfo_stderr ( message, header, **DEBUG=n )
#
#  Identical to veinfo(), buts prints the message to stderr
#  (instead of stdout).
#
veinfo_stderr() { veinfo "$@" 1>&2; }

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

# void veinfon_stderr ( message, header, **DEBUG=n )
#
#  Identical to veinfon(), buts prints the message to stderr
#  (instead of stdout).
#
veinfo_stderr() { veinfon "$@" 1>&2; }

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

# void message_indent ( **__MESSAGE_INDENT! )
#
message_indent() { __MESSAGE_INDENT="${__MESSAGE_INDENT-}  "; }

# void message_outdent ( **__MESSAGE_INDENT )
#
message_outdent() {
   if [ -n "${__MESSAGE_INDENT-}" ]; then
      __MESSAGE_INDENT="${__MESSAGE_INDENT% }"
      __MESSAGE_INDENT="${__MESSAGE_INDENT% }"
      return 0
   else
      return 1
   fi
}

# ~int message_indent_call ( *cmdv )
#
message_indent_call() {
   local __MESSAGE_INDENT="${__MESSAGE_INDENT-}"
   message_indent
   "$@"
}

# void message_autoset_nocolor ( force_rebind=n, **NO_COLOR! )
#
#  Sets NO_COLOR to 'y' if any of the following conditions are met:
#  * /NO_COLOR exists (can also be a broken symlink)
#  * stdout or stderr are not connected to a tty
#  * stdin is connected to a special terminal, e.g. serial console (ttyS*)
#  * /dev/null is missing, which prevents the ttyS* check
#
#  Automatically rebinds the message functions if necessary or
#  if %force_rebind is set to 'y'.
#
#  Note that this function never sets NO_COLOR=n.
#
message_autoset_nocolor() {
   if [ "${NO_COLOR:-n}" != "y" ]; then
      if \
         [ -e /NO_COLOR ] || [ -h /NO_COLOR ] || \
         [ ! -t 1 ] || [ ! -t 2 ]
      then
         NO_COLOR=y

      elif [ -c /dev/null ]; then
         case "$(tty 2>/dev/null)" in
            ttyS*|/*/ttyS*)
               # stdin from serial console, disable color
               NO_COLOR=y
            ;;
         esac

      elif tty | grep ttyS; then
         NO_COLOR=y
      fi
   fi

   # assert ${HAVE_COLORED_MESSAGE_FUNCTIONS:-y} in y n
   # * NO_COLOR <=> (not HAVE_COLORED_MESSAGE_FUNCTIONS)
   #
   if \
      [ "${1:-n}" = "y" ] || \
      [ "${NO_COLOR:-n}" = "${HAVE_COLORED_MESSAGE_FUNCTIONS:-y}" ]
   then
      message_bind_functions
   fi
}


#@section module_init

# @implicit void main ( **MESSAGE_BIND_FUNCTIONS=y )
#
#  Binds the message functions if %MESSAGE_BIND_FUNCTIONS is set to 'y'.
#
: ${__F_MESSAGE_EMITTER:="__message_nocolor"}
[ "${MESSAGE_BIND_FUNCTIONS:-y}" != "y" ] || message_bind_functions
