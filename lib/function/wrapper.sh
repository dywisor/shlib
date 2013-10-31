# void eval_function ( func_name, *code )
#
#  Creates a function.
#
eval_function() {
   local func_name="${1:?}"
   shift
   eval "\
${func_name}() {
   $@
}"
}

# void eval_nullfunc ( *func_name )
#
#  Creates zero or more no-op functions.
#
eval_nullfunc() {
   while [ $# -gt 0 ]; do
      [ -z "${1}" ] || eval_function "${1}" "return 0"
      shift
   done
}

# void function_alias ( func, func_alias, *pos_args )
#
#  Creates a function alias %func_alias->%func(*pos_args,*args).
#
function_alias() {
   local func="${1:?}"; local func_alias="${2:?}"
   shift 2
   eval "${func_alias}() { ${func} $@ \"\$@\"; }"
}
