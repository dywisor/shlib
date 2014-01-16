#@section functions

# void dodir_create_keepfile ( dir, **KEEPDIR=n )
#
dodir_create_keepfile() {
   if [ "${KEEPDIR:-n}" = "y" ] && [ ! -e "${1}/.keep" ]; then
      touch "${1}/.keep" || true
   fi
}

# int dodir_minimal (
#    dir, **KEEPDIR=n, **MKDIR_OPTS="-p", **MKDIR_OPTS_APPEND=
# )
#
#  Ensures that the given directory exists by creating it if necessary.
#  Also creates a <dir>/.keep file if **KEEPDIR is set to 'y'.
#
#  Returns 0 if the directory exists (at the end of this function),
#  else 1.
#
dodir_minimal() {
   if \
      [ -d "${1:?}" ] || \
      mkdir ${MKDIR_OPTS--p} ${MKDIR_OPTS_APPEND-} -- "${1}" 2>/dev/null || \
      [ -d "${1}" ]
   then
      dodir_create_keepfile "${1}"
      return 0
   else
      return 1
   fi
}

# int dodir_clean ( *dir, **KEEPDIR=n )
#
#  Ensures that the given directories exist by creating then if necessary.
#  Also creates a <dir>/.keep file if **KEEPDIR is set to 'y'.
#
#  (Calls dodir_minimal ( <dir> ) for each <dir> in *dir.)
#
#  Returns the number of directories that could not be created.
#
dodir_clean() {
   local fail=0
   while [ $# -gt 0 ]; do
      dodir_minimal "${1}" || fail=$(( ${fail} + 1 ))
      shift
   done
   return ${fail}
}

# @function_alias keepdir_clean ( *dir )
#  is KEEPDIR=y dodir_clean ( *dir )
#
keepdir_clean() {
   local KEEPDIR=y
   dodir_clean "$@"
}
