# @noreturn assert_die ( message, exit_code= ), raises die()
#
#  DEFINES @assert <function name> ( <arg> ), raises assert_die()
#
assert_die() {
   die "assertion error: ${1}" "${2-}"
}

# @assert void assert_list_has     ( word, list )
# @assert void assert_list_has_not ( word, list )
#
#  Assert function that test list membership.
#
assert_list_has() {
   if ! list_has "$@"; then
      local word="${1}"; shift
      assert_die "'${word}' not in list '$*'."
   fi
}
assert_list_has_not() {
   if list_has "$@"; then
      local word="${1}"; shift
      assert_die "'${word}' in list '$*', but it shouldn't."
   fi
}

# @assert void assert_function_defined ( *func )
#
assert_function_defined() {
   local f
   while [ $# -gt 0 ]; do
      f="${1%%(*}"; f="${f%% *}"
      function_defined "${f}" || assert_die "function '${1}' is not defined."
      shift
   done
}

# @assert void assert_retcode ( retcode, *argv )
#
#  Runs *argv and dies if the return code is unexpected, i.e. not retcode.
#
assert_retcode() {
   local rc=0 rc_expected="${1:?}"
   shift
   "$@" || rc=$?
   if [ ${rc} -ne ${rc_expected} ]; then
      assert_die "return code of command '$*' is ${rc}, but expected ${rc_expected}."
   fi
}


# void assert ( <expr> ), raises die(), assert_die()
#
#  Known expressions:
#  <word> in <list...>
#  <word> not in <list...>
#  <int> == <command...>
#
assert() {

   if [ "x${1-}" = "xfunction_defined" ]; then
      shift || die
      assert_function_defined "$@"

   elif [ "x${2-}" = "xin" ]; then
      local word="${1}"
      shift 2 || die
      assert_list_has "${word}" "$@"

   elif [ "x${2-}" = "xnot" ] && [ "x${3-}" = "xin" ]; then
      local word="${1}"
      shift 3 || die
      assert_list_has_not "${word}" "$@"

   elif [ "x${2-}" = "x==" ]; then
      local want_rc="${1}"
      shift 2 || die
      assert_retcode "${want_rc}" "$@"

   else
      die "unknown assert() statement: '$*'"
   fi
}
