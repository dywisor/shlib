# call any shlib function as script
#

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

if function_defined "${SCRIPT_NAME}"; then
   shlib_call_wrap_v0 ${SCRIPT_NAME} "$@"
else
   die "no such function: '${1}'"
fi
