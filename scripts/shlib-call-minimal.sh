#@HEADER
# call any shlib function as script
#

#@section __main__

SHLIB_CALL_FUNCTION="${SCRIPT_NAME}"

if [ "${HAVE_SHLIB_INTROSPECTION:-n}" = "y" ]; then
   case "${1-}" in
      "${SHLIB_INSTROSPECTION_MAGIC_EXEC_WORD:?}")
         shift
         SHLIB_CALL_FUNCTION="__run__"
      ;;
      '--list-functions')
         shift
         SHLIB_CALL_FUNCTION="shlib_list_functions"
      ;;
      '--list-variables')
         shift
         SHLIB_CALL_FUNCTION="shlib_list_variables"
      ;;
   esac
fi

if function_defined "${SHLIB_CALL_FUNCTION}"; then
   shlib_call_wrap_v0 ${SHLIB_CALL_FUNCTION} "$@"
else
   die "no such function: '${SHLIB_CALL_FUNCTION}'"
fi
