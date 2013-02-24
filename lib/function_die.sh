if [ -z "${__HAVE_SHLIB_FUNCTION_DIE__:-}" ]; then
readonly __HAVE_SHLIB_FUNCTION_DIE__=y

# @noreturn function_die (
#    message,
#    function_name="unknown",
#    code=
# )
function_die() {
   die__function "${2:-unknown}" "${1:-}" "${3:-}"
}

fi
