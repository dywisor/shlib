#@section vars

: ${MAINSCRIPT_NAMESPACE:=mainscript}


#@section functions

mainscript_declare_function_alias() {
   local func_alias_name

   func_alias_name="${1:?}"; shift
   : ${1:?}

   function_alias_quoted \
      run_main_function \
      "${MAINSCRIPT_NAMESPACE:?}__alias_${func_alias_name}" \
      "$@"
}

get_main_function() {
   case "${1-}" in
      '')
         die "no command specified" ${EX_USAGE}
      ;;
      '-h'|'--help')
         get_main_function print_help
         return ${?}
      ;;
   esac

   MAIN_FUNCTION=

   local fiter

   for fiter in \
      "${MAINSCRIPT_NAMESPACE}__alias_${1}" \
      "${MAINSCRIPT_NAMESPACE}_${1}" \
      "${1}"
   do
      if function_defined "${fiter}"; then
         MAIN_FUNCTION="${fiter}"
         return 0
      fi
   done

   die "no such function: ${1}"
}

run_main_function() {
   local MAIN_FUNCTION

   get_main_function "${1-}" && shift || return

   "${MAIN_FUNCTION:?}" "$@"
}
