#@section functions

# void assert_pipe ( expected_value=0 )
#
#  Dies if PIPESTATUS != expected_value.
#
assert_pipe() {
   local -i p="${PIPESTATUS[0]}" c="${1:-0}"
   [[ ${p} -eq ${c} ]] || function_die "expected ${c}, but got ${p}."
}
