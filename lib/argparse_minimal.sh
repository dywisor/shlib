#@section functions

#@funcdef argparse_minimal_parser<namespace,name>
#  int <namespace>__<name> ( *argv, **arg, **doshift!, **breakparse! )
#

# int argparse_minimal_do_parse_global_options (
#    *argv_remainder, **arg,
#    **VERBOSE!, **QUIET!, **DEBUG!,
#    **doshift!, **breakparse!,
#    **ARGPARSE_EXIT_AFTER_HELP
# )
#
argparse_minimal_do_parse_global_options() {
   case "${arg}" in
      '-v'|'--verbose')
         VERBOSE=y; QUIET=n
      ;;
      '--no-verbose')
         VERBOSE=n; DEBUG=n
      ;;
      '-q'|'--quiet')
         DEBUG=n; VERBOSE=n; QUIET=y
      ;;
      '--no-quiet')
         QUIET=n
      ;;
      '--debug')
         DEBUG=y; VERBOSE=y; QUIET=n
      ;;
      '--no-debug')
         DEBUG=n
      ;;
      '-h'|'--help')
         if [ $$ -ne 1 ] && function_defined print_help; then
            print_help
            if [ "${ARGPARSE_EXIT_AFTER_HELP:-y}" = "y" ]; then
               exit 0
            fi
         fi
      ;;
      '--')
         breakparse=true
      ;;
      *)
         return 1
      ;;
   esac
}

# void argparse_minimal_parse_arg (
#    argparse_namespace, packed_list<parsers>,
#    *argv,
#    **ARGPARSE_DOSHIFT!
#    **ARGPARSE_DIE_ON_UKNOWN,
#    **F_ARGPARSE_ARG_UNKNOWN,
# )
#
argparse_minimal_parse_args() {
   ARGPARSE_DOSHIFT=0
   local parser_namespace
   parser_namespace="${1:?}"; shift || return

   local breakparse doshift arg parsers
   local _parse_success _parser
   # capture var
   local v0

   parsers="${1:?}"; shift || return

   breakparse=false
   while ! ${breakparse} && [ ${#} -gt 0  ]; do
      _parse_success=false

      for _parser in ${parsers?}; do
         doshift=1
         arg="${1}"

         if ${parser_namespace:?}__${_parser} "${@}"; then
            _parse_success=true
            break
         fi

         _parse_success=false
      done

      if ${_parse_success}; then
         true

      elif [ -n "${F_ARGPARSE_ARG_UNKNOWN-}" ]; then
         ${F_ARGPARSE_ARG_UNKNOWN} "${@}" || die

      elif [ $$ -eq 1 ]; then
         ${LOGGER:-true} --level=INFO "unknown arg ${1}"

      elif [ "${ARGPARSE_DIE_ON_UKNOWN:-y}" = "y" ]; then
         die "unknown arg: ${1}" ${EX_USAGE}

      fi

      if [ ${doshift} -ne 0 ]; then
         shift ${doshift} || die "shift(${doshift}): out of bounds"
         ARGPARSE_DOSHIFT=$(( ${ARGPARSE_DOSHIFT:?} + ${doshift} ))
      fi
   done
}
