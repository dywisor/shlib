#@section funcdef

# @virtual int <argparse_handle> (
#    *argv_remainder,
#    **arg,
#    **argno,
#    **opt,
#    **shortopt,
#    **longopt,
#    **real_arg,
#    **value,
#    **doshift!
# )
#
#  Functions that handles args and/or options.
#  The doshift variable can be used to let the argparse_parse() function
#  consume zero or more of the remaining args.
#


#@section functions

# void argparse_die ( message, code=**EX_USAGE=64 )
#
#  die() wrapper function.
#
argparse_die() { die "argparse: ${1-}" "${2:-${EX_USAGE:-64}}"; }


#@section functions

# @private void __argparse_print_help ( **<see function body> ), raises exit()
#
#  Prints a help message.
#
#  TODO
#
__argparse_print_help() {
   if [ -z "${SCRIPT_NAME-}" ]; then
      local SCRIPT_NAME="${0##*/}"
      SCRIPT_NAME="${SCRIPT_NAME%.*}"
   fi

echo "${SCRIPT_NAME} - ${HELP_DESCRIPTION:?}

${HELP_BODY-}\
${HELP_USAGE:-Usage: ${0##*/} [option [option...]]}

where option is:
${ARGPARSE_HELP_INDENT-}--quiet        ${ARGPARSE_HELP_SPACE-}(-q) -- be quiet
${ARGPARSE_HELP_INDENT-}--verbose      ${ARGPARSE_HELP_SPACE-}(-v) -- be verbose
${ARGPARSE_HELP_INDENT-}--debug        ${ARGPARSE_HELP_SPACE-}     -- enable debug mode
${ARGPARSE_HELP_INDENT-}--describe,
${ARGPARSE_HELP_INDENT-}--help         ${ARGPARSE_HELP_SPACE-}(-h) -- show this message\
${HELP_OPTIONS-}${HELP_FOOTER-}" | sed '${/^$/d}'

   if [ "${EXIT_AFTER_HELP:-y}" = "y" ]; then
      exit ${EXITCODE_HELP:-0}
   fi
}

# @argparse_handle __argparse_handle_internal (...)
#
__argparse_handle_internal() {
   case "${arg}" in
      '')
         # any leading empty arg has no meaning and should be ignored
         true
      ;;
      '--help'|'-h'|'--describe')
         if function_defined print_help; then
            print_help
         else
            __argparse_print_help
         fi
      ;;
      '--quiet'|'-q')
         VERBOSE=n
         QUIET=y
      ;;
      '--debug')
         DEBUG=y
      ;;
      '--no-debug')
         DEBUG=n
      ;;
      '--verbose'|'-v')
         QUIET=n
         VERBOSE=y
      ;;
      *)
         return 1
      ;;
   esac
   return 0
}


#@section functions

# @argparse_handle argparse_need_arg (...)
#
#  Calls die() if $1 is empty or unset. Also sets doshift to 1.
#
argparse_need_arg() {
   if [ -n "${1-}" ]; then
      doshift=1
   else
      argparse_die "one non-empty arg required after '${arg}'"
   fi
}

# @argparse_handle argparse_need_args ( num_args, ... )
#
#  Like argparse_need_arg, but checks for num_args non-empty args.
#  Also sets doshift to num_args.
#
argparse_need_args() {
   local nargs="${1:?}"
   shift
   if [ $# -lt ${nargs} ]; then
      argparse_die "${nargs} non-empty args required after '${arg}'."
   else
      local i=0
      while [ ${i} -lt ${nargs} ]; do
         if [ -z "${1-}" ]; then
            argparse_die "${nargs} non-empty args required after '${arg}', but only ${i} found."
         fi
         i=$(( ${i} + 1 ))
         shift
      done
   fi
   doshift=${nargs}
}


#@section functions

# @argparse_handle __argparse_handle_shortopt (
#    [ word ] :: [ *argv_remainder ], ...
# )
#
#  Handles each char in word as shortopt.
#
__argparse_handle_shortopt() {
   local shortopt="${1-}"
   if [ -n "${shortopt}" ]; then
      shift
      local opt="${shortopt}" arg="-${shortopt}"
      if ! __argparse_handle_internal; then
         if [ -n "${F_ARGPARSE_SHORTOPT-}" ]; then
            autodie ${F_ARGPARSE_SHORTOPT} "$@"
         else
            autodie ${F_ARGPARSE:?} "$@"
         fi
      fi
   fi
}

#@section functions

# @argparse_handle argparse_unknown (
#    **real_arg,
#    **ARGPARSE_LOG_UNKNOWN=
#  ), raises die()
#
#  Function that handles the "cannot understand arg" event.
#
#  Logs the event using ARGPARSE_LOG_UNKNOWN as log level if set,
#  else dies.
#
argparse_unknown() {
   if [ -z "${ARGPARSE_LOG_UNKNOWN-}" ]; then
      argparse_die "cannot handle arg '${real_arg}'"
   else
      ewarn "argparse: unknown arg '${real_arg}'." || true
   fi
}

# @private int argparse__get_parse_function (
#    name, **ARGPARSE_FUNCNAME_PREFIX="argparse_", **v0!
# )
#
#  Sets v0=%ARGPARSE_FUNCNAME_PREFIX%name and returns 0 if a function with
#  that name is defined, else 1.
#
argparse__get_parse_function() {
   v0="${ARGPARSE_FUNCNAME_PREFIX:-argparse_}${1:?}"
   function_defined "${v0}"
}

# void argparse_autodetect ( **F_ARGPARSE..., **ARGPARSE_FUNCNAME_PREFIX= )
#
#  Searches for default @argparse_handle functions.
#
argparse_autodetect() {
   local v0
   ! argparse__get_parse_function break    || F_ARGPARSE_BREAK="${v0}"
   ! argparse__get_parse_function shortopt || F_ARGPARSE_SHORTOPT="${v0}"
   ! argparse__get_parse_function longopt  || F_ARGPARSE_LONGOPT="${v0}"
   ! argparse__get_parse_function arg      || F_ARGPARSE_ARG="${v0}"
   ! argparse__get_parse_function any      || F_ARGPARSE="${v0}"
}

# void argparse_parse_from_file ( file, **F_ARGPARSE... )
#
#  Parses the first line of a file as argv.
#
argparse_parse_from_file() {
   local ARGV
   read ARGV < "${1:?}"
   argparse_parse ${ARGV}
}

# void argparse_parse ( *argv, **ARGPARSE_BREAK=y, **F_ARGPARSE... )
#
#  Pre-parse argv and call arg parser functions for each arg.
#
argparse_parse() {
   local real_arg arg argno value opt shortopt longopt doshift

   argno=0
   while [ $# -gt 0 ]; do
      argno=$(( ${argno} + 1 ))
      real_arg="${1-}"
      arg="${real_arg%%=*}"
      value="${real_arg#*=}"
      [ "x${value}" != "x${real_arg}" ] || value=""

      opt=""
      shortopt=""
      longopt=""

      doshift=0
      shift

      if ! __argparse_handle_internal; then
         case "${arg}" in
            --)
               if [ -n "${F_ARGPARSE_BREAK-}" ]; then
                  autodie ${F_ARGPARSE_BREAK} "$@"
               else
                  autodie ${F_ARGPARSE:?} "$@"
               fi
               [ "${ARGPARSE_BREAK:-y}" != "y" ] || return 0
            ;;
            --*)
               longopt="${arg#--}"
               opt="${longopt}"

               if [ -n "${F_ARGPARSE_LONGOPT-}" ]; then
                  autodie ${F_ARGPARSE_LONGOPT} "$@"
               else
                  autodie ${F_ARGPARSE:?} "$@"
               fi
            ;;
            -)
               if [ -n "${F_ARGPARSE_ARG-}" ]; then
                  autodie ${F_ARGPARSE_ARG} "$@"
               else
                  autodie ${F_ARGPARSE:?} "$@"
               fi
            ;;
            -*)
               charwise __argparse_handle_shortopt "${arg#-}" "$@"
            ;;
            *)
               if [ -n "${F_ARGPARSE_ARG-}" ]; then
                  autodie ${F_ARGPARSE_ARG} "$@"
               else
                  autodie ${F_ARGPARSE:?} "$@"
               fi
            ;;
         esac
      fi

      [ ${doshift} -lt 1 ] || shift ${doshift} || function_die
   done
}
