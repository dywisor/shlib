#@section const

# str SHLIB_INSTROSPECTION_MAGIC_EXEC_WORD
#
#  A string that should be recognized by shlib-call scripts for overriding
#  the requested function.
#
SHLIB_INSTROSPECTION_MAGIC_EXEC_WORD='%^-_shlib_exec_run%^-_'


#@section module_features
: ${HAVE_SHLIB_INTROSPECTION:=y}


#@section functions

# int shlib_subshell_exec_self ( *argv, **CHAINLOAD_SCRIPT= )
#
#  Re-executes this script in a subshell for self-analysis.
#
#  Needs /bin/bash.
#
shlib_subshell_exec_self() {
   if [ -n "${CHAINLOAD_SCRIPT-}" ]; then
      set -- "${SCRIPT_NAME?}" "${SHLIB_INSTROSPECTION_MAGIC_EXEC_WORD:?}" "$@"
   else
      set -- "${SHLIB_INSTROSPECTION_MAGIC_EXEC_WORD:?}" "$@"
   fi
   ( exec -c /bin/bash --noprofile --norc "${0}" "$@"; )
}

# @stdout void shlib_list_functions ( **CHAINLOAD_SCRIPT= )
#
#  Prints the functions of this script to stdout.
#
#  Needs /bin/bash.
#
shlib_list_functions() {
   shlib_subshell_exec_self declare -F | cut -b 12-
}

# @stdout void shlib_list_variables ( **CHAINLOAD_SCRIPT= )
#
#  Prints the variables (including their values) of this script to stdout.
#
#  Needs /bin/bash.
#
shlib_list_variables() {
   shlib_subshell_exec_self declare -p | \
      sed -r -e 's,^declare\s+[-][^\s]+\s+,,'
}
