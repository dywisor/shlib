#@section functions

# int as_function ( *argv, **MAIN_FUNCTION=**SCRIPT_NAME )
#
#  Calls a function named MAIN_FUNCTION or SCRIPT_NAME.
#  Scripts can use this in order to avoid infinite recursion.
#
as_function() {
   local func="${MAIN_FUNCTION:-${SCRIPT_NAME:?}}"
   if function_defined "${func}"; then
      ${func} "$@"
   else
      die "main function ${func} is not defined."
   fi
}

# @function_alias asf() renames as_function()
asf() { as_function "$@"; }
