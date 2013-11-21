#@section functions

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


#@section functions

# void autodie ( *argv, **F_AUTODIE=die__autodie )
#
#  Runs %F_AUTODIE ( *argv ) which is supposed to let the script die on
#  non-zero return code.
#
autodie() { ${F_AUTODIE:-die__autodie} "$@"; }

# @function_alias run() copies autodie()
#
run() { ${F_AUTODIE:-die__autodie} "$@"; }


#@section vars
# modules/scripts may want to use/set %AUTODIE, %AUTODIE_NONFATAL
# if autodie behavior is optional
: ${AUTODIE=}
: ${AUTODIE_NONFATAL=}
