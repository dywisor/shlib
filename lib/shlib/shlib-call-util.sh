#@section functions_export

# @extern @noreturn die ( message, code, **DIE=exit )
#
#  Prints %message to stderr and calls %DIE(code) afterwards.
#

#@extern int function_defined ( func )
#  @implemented_by int function_defined ( *func )
#
#  Returns 0 if %func is defined, else 1.
#

#@section functions

# int shlib_call_wrap_v0 ( *cmdv )
#
#  Executes *cmdv and prints v0 or FILESIZE to stdout afterwards (if set).
#  Passes cmdv's return value.
#
shlib_call_wrap_v0() {
   local v0 FILESIZE rc=0
   "$@" || rc=$?

   if [ -z "${v0-}" ]; then
      # compat "hack" for get_filesize()
      [ -z "${FILESIZE-}" ] || echo "${FILESIZE}"
   else
      echo "${v0}"
   fi
   return ${rc}
}
