# void assert_retcode ( retcode, *argv )
#
#  Runs *argv and dies if the return code is unexpected, i.e. not retcode.
#
assert_retcode() {
   local rc=0 rc_expected="${1:?}"
   shift
   "$@" || rc=$?
   if [ ${rc} -ne ${rc_expected} ]; then
      die "assertion error: return code of command '$*' is ${rc}, but expected ${rc_expected}."
   else
      return 0
   fi
}
