#@section vars

: ${MAINSCRIPT_NAMESPACE:=mainscript}


#@section functions

mainscript_declare_function_alias() {
   local func_alias_name

   func_alias_name="${1:?}"; shift

   function_alias_quoted \
      "${MAINSCRIPT_NAMESPACE:?}__alias_${func_alias_name}" "$@"
}

get_main_function() {
   func=
   [ -n "${1-}" ] || die "no command specified."

   local fiter

   for fiter in \
      "${MAINSCRIPT_NAMESPACE}__alias__${1}" \
      "${MAINSCRIPT_NAMESPACE}_${1}" \
      "${1}"
   do
      if function_defined "${fiter}"; then
         func="${fiter}"
         return 0
      fi
   done

   die "no such function: ${1}"
}

run_main_function() {
   local func
   get_main_function "${1-}" && shift && "${func:?}" "$@"
}
