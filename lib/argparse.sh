# @virtual int <argparse_handle> (
#    *argv_remainder,
#    **arg,
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

# void __argparse_print_help ( **<see function body> ), raises exit()
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
--quiet        (-q) -- be quiet
--verbose      (-v) -- be verbose
--debug             -- enable debug mode
--describe,
--help         (-h) -- show this message\
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

# @argparse_handle __argparse_handle_shortopt (
#    [ word ] :: [ *argv_remainder ], ...
# )
#
#  Handles each char in word as shortopt.
#
__argparse_handle_shortopt() {
   local shortopt="${1-}"
   if [ -n "${shortopt}" ]; then
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
      die "cannot handle arg '${real_arg}'"
   else
      LOG_LEVEL="${ARGPARSE_LOG_UNKNOWN}" dolog \
         --facility=argparse.unknown "${real_arg}" || true
   fi
}

# void argparse_autodetect ( **F_ARGPARSE... )
#
#  Searches for default @argparse_handle functions.
#
argparse_autodetect() {
   ! function_defined argparse_break    || F_ARGPARSE_BREAK=argparse_break
   ! function_defined argparse_shortopt || F_ARGPARSE_SHORTOPT=argparse_shortopt
   ! function_defined argparse_longopt  || F_ARGPARSE_LONGOPT=argparse_longopt
   ! function_defined argparse_arg      || F_ARGPARSE_ARG=argparse_arg
   ! function_defined argparse_any      || F_ARGPARSE=argparse_any
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

# void argparse_parse ( *argv, **F_ARGPARSE... )
#
#  Pre-parse argv and call arg parser functions for each arg.
#
argparse_parse() {
   local real_arg arg value opt shortopt longopt doshift

   while [ $# -gt 0 ]; do
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