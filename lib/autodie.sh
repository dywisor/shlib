# @private void die__autodie ( *argv )
#
#  Runs *argv. Dies on non-zero return code.
#
die__autodie() {
   if "$@"; then
      return 0
   else
      die "command '$*' returned $?."
   fi
}

# void autodie ( *argv, **AUTODIE=die__autodie )
#
#  Runs AUTODIE ( *argv ) which is supposed to let the script die on
#  non-zero return code.
#
autodie() { ${AUTODIE:-die__autodie} "$@"; }

# @function_alias run() copies autodie()
#
run() { ${AUTODIE:-die__autodie} "$@"; }
