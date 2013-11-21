#@section functions

# @noreturn function_die (
#    message,
#    function_name=@backtrace,
#    code=
# )
function_die() {
   if [ -n "${2:-}" ]; then
      die__function "${2}" "${1:-}" "${3:-}"
   else
      die__function "${FUNCNAME[1]}" "${1:-}" "${3:-}"
   fi
}
