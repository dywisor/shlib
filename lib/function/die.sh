#@section functions

# @noreturn function_die (
#    message,
#    function_name="unknown",
#    code=
# )
function_die() {
   die__function "${2:-unknown}" "${1:-}" "${3:-}"
}
