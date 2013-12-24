#@section __main__

if [ "${PACKSCRIPT_AS_LIB:-n}" = "y" ]; then
   : ${PACKSCRIPT_PROTECT_VARS:=y}
   : ${PACK_TARGET_IN_SUBSHELL:=y}
else
   : ${PACKSCRIPT_PROTECT_VARS:=n}
   : ${PACK_TARGET_IN_SUBSHELL:=n}
   packscript_main "$@"
fi
